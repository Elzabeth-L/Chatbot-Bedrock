output "api_gateway_invoke_url" {
  description = "HTTP API invoke URL."
  value       = aws_apigatewayv2_api.chat.api_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront frontend domain."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_data_source_id" {
  value = aws_bedrockagent_data_source.documents.data_source_id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.sessions.name
}

output "source_document_bucket_name" {
  value = aws_s3_bucket.documents.id
}

output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend.id
}

output "selected_generation_model_id" {
  value = data.aws_ssm_parameter.generation_model_id.value
}

output "selected_embedding_model_id" {
  value = var.embedding_model_id
}

output "sns_alert_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "budget_name" {
  value = aws_budgets_budget.monthly.name
}
