# Assumptions, cost risks, and provider limitations

## Assumptions

- The deployment account can activate/invoke Nova Micro and Titan Text Embeddings
  V2 in `us-east-1`.
- The existing GitHub OIDC deployment role can create the listed resources and read
  and lock the pre-existing state object.
- The existing backend bucket is versioned, encrypted, and blocked from public
  access; this module neither creates nor changes it.
- The demo corpus is small and contains redistribution-safe, repository-authored
  summaries that link to official documentation rather than copied manuals.
- An unauthenticated API is acceptable for this demonstration.

## Cost risks

- Bedrock generation and embedding ingestion are billed by usage.
- S3 Vectors storage/query operations are billed and can continue while deployed.
- API Gateway, Lambda, DynamoDB, S3, CloudFront, logs, SNS, and monitoring may incur
  usage charges beyond free allowances.
- Promotional credits can expire.
- AWS Budgets alert but never stop resources or requests.
- Public API abuse can create model charges. Mitigations are route throttles, bounded
  input/history/output, alarms, short log retention, and the mandatory budget.
- The environment should be destroyed when the demonstration ends.

## Technical and provider limitations

- AWS provider 6.55.x is required for the planned native S3 Vectors support. Older
  locks/providers will fail validation.
- Terraform can create the Knowledge Base and data source but ingestion completes
  asynchronously. A successful apply does not prove documents are immediately
  retrievable.
- S3 Vectors supports semantic rather than hybrid search.
- DynamoDB TTL deletion is best effort. Application reads must filter expired items.
- API Gateway HTTP API throttling is stage-level; it is a cost control, not strong
  abuse prevention.
- CloudFront/API circular configuration is avoided by setting CORS to the predicted
  CloudFront distribution domain once available in the same Terraform graph. If the
  AWS API rejects an unknown value during creation, a two-apply convergence may be
  required and will be documented.
- Binary Terraform plans are environment-specific. Artifact application requires a
  Linux x86_64 runner, exact Terraform version, locked providers, same path,
  configuration commit, backend identity, and variables.
- GitHub artifacts expire and workflow artifacts from forks are untrusted. Apply
  requires an unexpired artifact from an authorized run in the same repository.
- Model access, AWS account quotas, an existing backend bucket, and an existing OIDC
  role cannot be validated locally.
- SonarCloud and Snyk gates require configured repository integrations and
  `SONAR_TOKEN`/`SNYK_TOKEN` GitHub Secrets. When absent, the workflow reports that
  the corresponding external scan was skipped.
- Lambda and frontend delivery use only Terraform ZIP/S3 packaging.

## Cost-first choices

- S3 Vectors instead of an always-on vector service
- API Gateway HTTP API
- No VPC, NAT Gateway, WAF, Cognito, or provisioned Bedrock throughput
- On-demand DynamoDB
- Small Lambda memory, bounded timeout, and short log retention
- CloudFront Price Class 100
- AWS-managed encryption keys where a customer-managed key would add recurring cost
- Small corpus, 256-dimensional embeddings, bounded retrieved results and history
- Demo buckets default to `force_destroy=true` so the explicitly confirmed,
  reviewed destroy plan removes retained versions and vectors

## Pre-deployment revalidation

Before the first apply, confirm current Region/model compatibility, model access,
S3 Vectors availability, account service quotas, backend security, OIDC trust
conditions, budget amount, and optional SNS email. Provider schema validation and a
reviewed Terraform plan remain mandatory.
