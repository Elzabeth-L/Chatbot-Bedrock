variable "aws_region" {
  description = "AWS Region containing the Terraform state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid lowercase S3 bucket name."
  }
}

variable "state_key" {
  description = "Exact S3 object key used by the application Terraform backend."
  type        = string
  default     = "bedrock-rag-demo/demo/terraform.tfstate"
}

variable "tags" {
  description = "Non-sensitive tags applied to the bootstrap bucket."
  type        = map(string)
  default = {
    Project   = "Chatbot-Bedrock"
    ManagedBy = "Bootstrap"
    Purpose   = "Terraform-State"
  }
}

variable "github_owner" {
  type    = string
  default = "Elzabeth-L"
}

variable "github_owner_id" {
  type    = string
  default = "262315662"
}

variable "github_repository" {
  type    = string
  default = "Chatbot-Bedrock"
}

variable "github_repository_id" {
  type    = string
  default = "1314924557"
}

variable "feature_branch" {
  type    = string
  default = "feature/initial-bedrock-rag"
}
