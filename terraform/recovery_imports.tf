# One-time recovery imports for the first application apply, which created these
# resources before the deployment role was able to persist state. Import blocks
# are idempotent after the resources have been adopted into the backend state.

locals {
  recovery_frontend_bucket   = "bedrock-rag-demo-demo-frontend-9a6e24d4024e08946a39f6f33a"
  recovery_documents_bucket  = "bedrock-rag-demo-demo-documents-263943e01bc561f829de442683"
  recovery_kb_role           = "bedrock-rag-demo-demo-kb-0ab03cd2ae7f330e0da4f57162"
  recovery_kb_policy         = "knowledge-base-5ad5213b8c985daffd56e8f08b"
  recovery_alerts_arn        = "arn:${data.aws_partition.current.partition}:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:bedrock-rag-demo-demo-alerts"
  recovery_vector_bucket_arn = "arn:${data.aws_partition.current.partition}:s3vectors:${var.aws_region}:${data.aws_caller_identity.current.account_id}:bucket/bedrock-rag-demo-demo-vectors"
}

import {
  to = aws_cloudfront_response_headers_policy.security
  id = "316306a9-914f-4e4d-93e6-71c59bb1abba"
}

import {
  to = aws_ssm_parameter.generation_model_id
  id = "/bedrock-rag-demo-demo/bedrock/generation-model-id"
}

import {
  to = aws_cloudwatch_log_group.chat
  id = "/aws/lambda/bedrock-rag-demo-demo-chat"
}

import {
  to = aws_cloudwatch_log_group.ingestion
  id = "/aws/lambda/bedrock-rag-demo-demo-ingestion"
}

import {
  to = aws_cloudwatch_log_group.api
  id = "/aws/apigateway/bedrock-rag-demo-demo"
}

import {
  to = aws_iam_role.ingestion
  id = "bedrock-rag-demo-demo-ingest-5ce6a6f6dee2d4c33a4cb90d59"
}

import {
  to = aws_iam_role.chat
  id = "bedrock-rag-demo-demo-chat-25c0013b6fb11ba13e7d182a33"
}

import {
  to = aws_iam_role.knowledge_base
  id = local.recovery_kb_role
}

import {
  to = aws_sns_topic.alerts
  id = local.recovery_alerts_arn
}

import {
  to = aws_cloudfront_origin_access_control.frontend
  id = "E3C4HZ4IRA1PM1"
}

import {
  to = aws_sns_topic_policy.alerts
  id = local.recovery_alerts_arn
}

import {
  to = aws_s3vectors_vector_bucket.knowledge_base
  id = local.recovery_vector_bucket_arn
}

import {
  to = aws_s3vectors_index.knowledge_base
  id = "${local.recovery_vector_bucket_arn}/index/technical-documents"
}

import {
  to = aws_s3_bucket.frontend
  id = local.recovery_frontend_bucket
}

import {
  to = aws_s3_bucket.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_s3_bucket_public_access_block.frontend
  id = local.recovery_frontend_bucket
}

import {
  to = aws_s3_bucket_public_access_block.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_s3_object.frontend_index
  id = "${local.recovery_frontend_bucket}/index.html"
}

import {
  to = aws_s3_object.frontend_styles
  id = "${local.recovery_frontend_bucket}/styles.css"
}

import {
  to = aws_s3_object.frontend_app
  id = "${local.recovery_frontend_bucket}/app.js"
}

import {
  to = aws_s3_bucket_ownership_controls.frontend
  id = local.recovery_frontend_bucket
}

import {
  to = aws_s3_bucket_ownership_controls.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.frontend
  id = local.recovery_frontend_bucket
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_iam_role_policy.knowledge_base
  id = "${local.recovery_kb_role}:${local.recovery_kb_policy}"
}

import {
  to = aws_s3_bucket_policy.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_s3_bucket_versioning.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_sqs_queue.ingestion_dlq
  id = "https://sqs.${var.aws_region}.amazonaws.com/${data.aws_caller_identity.current.account_id}/bedrock-rag-demo-demo-ingestion-dlq"
}

import {
  to = aws_s3_bucket_lifecycle_configuration.documents
  id = local.recovery_documents_bucket
}

import {
  to = aws_cloudfront_distribution.frontend
  id = "E3T00LJCV4C2RR"
}

import {
  to = aws_dynamodb_table.sessions
  id = "bedrock-rag-demo-demo-sessions"
}
