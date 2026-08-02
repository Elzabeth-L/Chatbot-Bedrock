variable "project_name" {
  description = "Short lowercase project name used in resource names."
  type        = string
  default     = "bedrock-rag-demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,24}$", var.project_name))
    error_message = "project_name must be 3-25 lowercase letters, digits, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,11}$", var.environment))
    error_message = "environment must be 2-12 lowercase letters, digits, or hyphens."
  }
}

variable "aws_region" {
  description = "AWS Region. Revalidate all Bedrock compatibility before changing."
  type        = string
  default     = "us-east-1"
}

variable "generation_model_id" {
  description = "Bedrock generation model ID stored in SSM at deployment."
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "generation_model_arn_override" {
  description = "Optional full inference-profile/model ARN for IDs that are not direct foundation models."
  type        = string
  default     = null
  nullable    = true
}

variable "embedding_model_id" {
  description = "Bedrock embedding model ID."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimensions" {
  description = "Embedding/index dimensions; must be supported by the selected embedding model."
  type        = number
  default     = 256
  validation {
    condition     = contains([256, 512, 1024], var.embedding_dimensions)
    error_message = "embedding_dimensions must be 256, 512, or 1024."
  }
}

variable "session_retention_hours" {
  description = "Per-message session history retention."
  type        = number
  default     = 24
  validation {
    condition     = var.session_retention_hours >= 1 && var.session_retention_hours <= 720
    error_message = "session_retention_hours must be between 1 and 720."
  }
}

variable "monthly_budget_usd" {
  description = "Mandatory monthly AWS cost budget amount in USD."
  type        = number
  default     = 10
  validation {
    condition     = var.monthly_budget_usd >= 1
    error_message = "monthly_budget_usd must be at least 1."
  }
}

variable "alert_email" {
  description = "Optional alert email. AWS sends a confirmation request."
  type        = string
  default     = null
  nullable    = true
  validation {
    condition     = var.alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be null or a valid email-shaped value."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Use a supported cost-conscious retention value."
  }
}

variable "lambda_error_rate_threshold" {
  description = "Lambda error percentage alarm threshold."
  type        = number
  default     = 5
}

variable "api_5xx_threshold" {
  description = "HTTP API 5xx count alarm threshold per period."
  type        = number
  default     = 3
}

variable "dynamodb_throttle_threshold" {
  description = "DynamoDB throttled request count alarm threshold."
  type        = number
  default     = 1
}

variable "api_throttle_rate" {
  description = "HTTP API sustained request rate."
  type        = number
  default     = 5
}

variable "api_throttle_burst" {
  description = "HTTP API burst request limit."
  type        = number
  default     = 10
}

variable "force_destroy_buckets" {
  description = "Allow demo buckets/vector bucket to be emptied during destroy."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags for supported resources."
  type        = map(string)
  default     = {}
}
