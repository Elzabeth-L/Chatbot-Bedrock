resource "aws_cloudwatch_log_group" "chat" {
  name              = "/aws/lambda/${local.name_prefix}-chat"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "ingestion" {
  name              = "/aws/lambda/${local.name_prefix}-ingestion"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "chat" {
  function_name    = "${local.name_prefix}-chat"
  role             = aws_iam_role.chat.arn
  runtime          = "python3.13"
  handler          = "handler.handler"
  filename         = data.archive_file.chat.output_path
  source_code_hash = data.archive_file.chat.output_base64sha256
  memory_size      = 512
  timeout          = 45

  environment {
    variables = {
      TABLE_NAME                    = aws_dynamodb_table.sessions.name
      KNOWLEDGE_BASE_ID             = data.aws_ssm_parameter.knowledge_base_id.value
      GENERATION_MODEL_ARN          = local.generation_model_arn
      GENERATION_MODEL_ID           = data.aws_ssm_parameter.generation_model_id.value
      SESSION_TTL_SECONDS           = tostring(var.session_retention_hours * 3600)
      MAX_MESSAGE_LENGTH            = "2000"
      MAX_HISTORY_MESSAGES          = "12"
      MAX_HISTORY_RESPONSE_MESSAGES = "100"
      MAX_CITATIONS                 = "5"
      LOG_LEVEL                     = "INFO"
    }
  }

  depends_on = [aws_iam_role_policy.chat, aws_cloudwatch_log_group.chat]
}

resource "aws_sqs_queue" "ingestion_dlq" {
  name                      = "${local.name_prefix}-ingestion-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "ingestion" {
  name                       = "${local.name_prefix}-ingestion"
  visibility_timeout_seconds = 480
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingestion_dlq.arn
    maxReceiveCount     = 8
  })
}

data "aws_iam_policy_document" "ingestion_queue" {
  statement {
    sid       = "AllowDocumentBucketNotifications"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ingestion.arn]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.documents.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sqs_queue_policy" "ingestion" {
  queue_url = aws_sqs_queue.ingestion.id
  policy    = data.aws_iam_policy_document.ingestion_queue.json
}

resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id
  queue {
    queue_arn     = aws_sqs_queue.ingestion.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_prefix = local.kb_prefix
  }
  depends_on = [aws_sqs_queue_policy.ingestion]
}

resource "aws_lambda_function" "ingestion" {
  function_name                  = "${local.name_prefix}-ingestion"
  role                           = aws_iam_role.ingestion.arn
  runtime                        = "python3.13"
  handler                        = "handler.handler"
  filename                       = data.archive_file.ingestion.output_path
  source_code_hash               = data.archive_file.ingestion.output_base64sha256
  memory_size                    = 256
  timeout                        = 60
  reserved_concurrent_executions = 1

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.this.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.documents.data_source_id
      LOG_LEVEL         = "INFO"
    }
  }

  depends_on = [aws_iam_role_policy.ingestion, aws_cloudwatch_log_group.ingestion]
}

resource "aws_lambda_event_source_mapping" "ingestion" {
  event_source_arn                   = aws_sqs_queue.ingestion.arn
  function_name                      = aws_lambda_function.ingestion.arn
  batch_size                         = 100
  maximum_batching_window_in_seconds = 60
  function_response_types            = ["ReportBatchItemFailures"]
  enabled                            = true
}
