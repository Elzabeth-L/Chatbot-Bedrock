# Terraform configuration basics

Terraform is an infrastructure-as-code tool. A configuration describes desired
infrastructure in HashiCorp Configuration Language. Providers translate resource
blocks into calls to service APIs.

The normal workflow is:

1. `terraform fmt` normalizes configuration formatting.
2. `terraform init` installs providers and initializes the backend.
3. `terraform validate` checks configuration syntax and internal consistency.
4. `terraform plan` compares configuration with current state and proposes changes.
5. `terraform apply` performs the changes recorded in a plan.

Remote state allows a team to share the mapping between configuration and deployed
objects. State can contain sensitive data and must be protected. An S3 backend can
use an S3 lockfile to prevent concurrent state modification. Provider dependency
versions belong in the committed `.terraform.lock.hcl` file.

Source: Terraform documentation, https://developer.hashicorp.com/terraform/docs
