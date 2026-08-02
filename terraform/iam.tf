data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "knowledge_base_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "knowledge_base" {
  name_prefix        = "${local.name_prefix}-kb-"
  assume_role_policy = data.aws_iam_policy_document.knowledge_base_trust.json
}

data "aws_iam_policy_document" "knowledge_base" {
  statement {
    sid       = "ReadSourceBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.documents.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.kb_prefix}*"]
    }
  }
  statement {
    sid       = "ReadSourceObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.documents.arn}/${local.kb_prefix}*"]
  }
  statement {
    sid       = "InvokeEmbeddingModel"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.embedding_model_arn]
  }
  statement {
    sid = "UseVectorIndex"
    actions = [
      "s3vectors:DeleteVectors",
      "s3vectors:GetIndex",
      "s3vectors:GetVectors",
      "s3vectors:PutVectors",
      "s3vectors:QueryVectors"
    ]
    resources = [aws_s3vectors_index.knowledge_base.index_arn]
  }
}

resource "aws_iam_role_policy" "knowledge_base" {
  name_prefix = "knowledge-base-"
  role        = aws_iam_role.knowledge_base.id
  policy      = data.aws_iam_policy_document.knowledge_base.json
}

resource "aws_iam_role" "chat" {
  name_prefix        = "${local.name_prefix}-chat-"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "chat" {
  statement {
    sid       = "WriteFunctionLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.chat.arn}:*"]
  }
  statement {
    sid = "UseSessionTable"
    actions = [
      "dynamodb:BatchWriteItem",
      "dynamodb:PutItem",
      "dynamodb:Query"
    ]
    resources = [aws_dynamodb_table.sessions.arn]
  }
  statement {
    sid     = "RetrieveAndGenerate"
    actions = ["bedrock:RetrieveAndGenerate"]
    # AWS does not currently support resource-level authorization for this action.
    # Retrieval remains constrained at runtime to the injected Knowledge Base ID.
    resources = ["*"]
  }
  statement {
    sid       = "InvokeGenerationModel"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.generation_model_arn]
  }
}

resource "aws_iam_role_policy" "chat" {
  name_prefix = "chat-"
  role        = aws_iam_role.chat.id
  policy      = data.aws_iam_policy_document.chat.json
}

resource "aws_iam_role" "ingestion" {
  name_prefix        = "${local.name_prefix}-ingest-"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

data "aws_iam_policy_document" "ingestion" {
  statement {
    sid       = "WriteFunctionLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.ingestion.arn}:*"]
  }
  statement {
    sid = "ConsumeDocumentEvents"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]
    resources = [aws_sqs_queue.ingestion.arn]
  }
  statement {
    sid       = "ManageDataSourceIngestion"
    actions   = ["bedrock:ListIngestionJobs", "bedrock:StartIngestionJob"]
    resources = [aws_bedrockagent_knowledge_base.this.arn]
  }
}

resource "aws_iam_role_policy" "ingestion" {
  name_prefix = "ingestion-"
  role        = aws_iam_role.ingestion.id
  policy      = data.aws_iam_policy_document.ingestion.json
}
