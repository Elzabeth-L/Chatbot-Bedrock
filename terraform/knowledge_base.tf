resource "aws_s3vectors_vector_bucket" "knowledge_base" {
  vector_bucket_name = "${local.name_prefix}-vectors"
  force_destroy      = var.force_destroy_buckets
  encryption_configuration {
    sse_type = "AES256"
  }
}

resource "aws_s3vectors_index" "knowledge_base" {
  index_name         = "technical-documents"
  vector_bucket_name = aws_s3vectors_vector_bucket.knowledge_base.vector_bucket_name
  data_type          = "float32"
  dimension          = var.embedding_dimensions
  distance_metric    = "cosine"
}

data "aws_iam_policy_document" "vector_bucket" {
  statement {
    sid    = "AllowKnowledgeBaseVectorOperations"
    effect = "Allow"
    actions = [
      "s3vectors:DeleteVectors",
      "s3vectors:GetIndex",
      "s3vectors:GetVectors",
      "s3vectors:PutVectors",
      "s3vectors:QueryVectors"
    ]
    resources = [aws_s3vectors_index.knowledge_base.index_arn]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [aws_iam_role.knowledge_base.arn]
    }
  }
}

resource "aws_s3vectors_vector_bucket_policy" "knowledge_base" {
  vector_bucket_arn = aws_s3vectors_vector_bucket.knowledge_base.vector_bucket_arn
  policy            = data.aws_iam_policy_document.vector_bucket.json
  depends_on        = [aws_iam_role_policy.knowledge_base]
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${local.name_prefix}-kb"
  role_arn = aws_iam_role.knowledge_base.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.knowledge_base.index_arn
    }
  }

  depends_on = [
    aws_iam_role_policy.knowledge_base,
    aws_s3vectors_vector_bucket_policy.knowledge_base
  ]
}

resource "aws_bedrockagent_data_source" "documents" {
  name                 = "${local.name_prefix}-documents"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  data_deletion_policy = "DELETE"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.documents.arn
      inclusion_prefixes = [local.kb_prefix]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 500
        overlap_percentage = 15
      }
    }
  }
}

resource "aws_ssm_parameter" "generation_model_id" {
  name        = "/${local.name_prefix}/bedrock/generation-model-id"
  description = "Terraform-managed Bedrock generation model ID."
  type        = "String"
  value       = var.generation_model_id
}

resource "aws_ssm_parameter" "knowledge_base_id" {
  name        = "/${local.name_prefix}/bedrock/knowledge-base-id"
  description = "Terraform-managed Bedrock Knowledge Base ID."
  type        = "String"
  value       = aws_bedrockagent_knowledge_base.this.id
}
