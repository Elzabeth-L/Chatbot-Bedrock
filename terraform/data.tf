data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "generation_model_id" {
  name       = aws_ssm_parameter.generation_model_id.name
  depends_on = [aws_ssm_parameter.generation_model_id]
}

data "aws_ssm_parameter" "knowledge_base_id" {
  name       = aws_ssm_parameter.knowledge_base_id.name
  depends_on = [aws_ssm_parameter.knowledge_base_id]
}

data "archive_file" "chat" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/chat"
  output_path = "${path.module}/chat-lambda.zip"
}

data "archive_file" "ingestion" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/ingestion"
  output_path = "${path.module}/ingestion-lambda.zip"
}
