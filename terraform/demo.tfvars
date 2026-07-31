# Non-secret demonstration defaults used by GitHub Actions.
project_name            = "bedrock-rag-demo"
environment             = "demo"
aws_region              = "us-east-1"
generation_model_id     = "amazon.nova-micro-v1:0"
embedding_model_id      = "amazon.titan-embed-text-v2:0"
embedding_dimensions    = 256
session_retention_hours = 24
monthly_budget_usd      = 10
alert_email             = null
force_destroy_buckets   = true
