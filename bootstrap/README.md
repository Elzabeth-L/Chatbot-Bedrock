# Terraform backend bootstrap

This Terraform root is run locally and is not called by either GitHub Actions
workflow. It owns the S3 bucket used by the application Terraform backend plus the
trust configuration and supplemental permissions of the two repository-scoped
GitHub OIDC roles.
Bootstrap state remains local and gitignored because the locally installed
Terraform 1.12.2 S3 backend cannot consume the newer `aws login` credential source.
The resources can be safely re-imported if that local state is lost. The application
workflow remains pinned independently to Terraform 1.15.8 and writes application
state to the managed S3 bucket through GitHub OIDC credentials.

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
