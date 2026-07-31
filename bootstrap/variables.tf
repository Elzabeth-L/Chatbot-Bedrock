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

variable "tags" {
  description = "Non-sensitive tags applied to the bootstrap bucket."
  type        = map(string)
  default = {
    Project   = "Chatbot-Bedrock"
    ManagedBy = "Bootstrap"
    Purpose   = "Terraform-State"
  }
}
