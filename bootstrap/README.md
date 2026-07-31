# Terraform backend bootstrap

This Terraform root is run locally and is not called by either GitHub Actions
workflow. It owns only the S3 bucket used by the application Terraform backend.
Its local state is ignored by Git. The bootstrap uses only stable S3 resources and
supports the locally installed Terraform 1.12.2; the application workflow remains
pinned independently to Terraform 1.15.8.

For a new bucket:

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -var-file=bootstrap.tfvars
terraform -chdir=bootstrap apply -var-file=bootstrap.tfvars
```

The configured bucket already exists from the earlier manual bootstrap. Adopt it
without deleting or recreating the globally unique name:

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket_versioning.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket_server_side_encryption_configuration.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket_public_access_block.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket_ownership_controls.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap import -var-file=bootstrap.tfvars aws_s3_bucket_policy.state elzabeth-l-chatbot-bedrock-tfstate-6074cb42d1
terraform -chdir=bootstrap plan -var-file=bootstrap.tfvars
terraform -chdir=bootstrap apply -var-file=bootstrap.tfvars
```

Never run `terraform destroy` for this root. The bucket resource uses
`prevent_destroy` because deleting it would remove the backend recovery history.
Do not commit bootstrap state or AWS credentials.
