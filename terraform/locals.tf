locals {
  name_prefix = lower("${var.project_name}-${var.environment}")
  kb_prefix   = "knowledge-base/documents/"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  generation_model_arn = coalesce(
    var.generation_model_arn_override,
    "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${data.aws_ssm_parameter.generation_model_id.value}"
  )
  embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}::foundation-model/${var.embedding_model_id}"
  api_origin          = aws_apigatewayv2_api.chat.api_endpoint
  frontend_origin     = "https://${aws_cloudfront_distribution.frontend.domain_name}"

  document_files = fileset("${path.module}/../documents", "**")
}
