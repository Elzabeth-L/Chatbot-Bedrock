# Technology decisions

Decision date: 2026-07-28. Availability must be rechecked before deployment because
AWS service and model support changes over time.

## Region: US East (N. Virginia), `us-east-1`

Selected because current AWS documentation shows:

- In-Region Amazon Nova Micro support.
- Titan Text Embeddings V2 support.
- Bedrock Knowledge Bases and S3 Vectors coexist in the Region.
- Mature availability for the other serverless services used here.

The Region is configurable. A non-default Region is rejected operationally until
the operator confirms all three Bedrock compatibility dimensions.

## Generation: Amazon Nova Micro

Default model ID: `amazon.nova-micro-v1:0`.

Nova Micro is text-only, low latency, and the first low-cost preference in the
requirements. In `us-east-1` it supports direct In-Region inference, so the initial
implementation uses a foundation-model ARN rather than a cross-Region inference
profile. A configurable model ID permits Nova Lite or an inference-profile ID if
account availability later requires it.

## Embeddings: Titan Text Embeddings V2

Default model ID: `amazon.titan-embed-text-v2:0`.

Use 256 float32 dimensions. This is the smallest supported Titan V2 dimension and
is suitable for a small technical-document demonstration, reducing vector storage.
The model ID remains configurable, but its dimension and index compatibility must
be changed together.

## Vector store: S3 Vectors

Selected. AWS provider 6.55.0 has native `aws_s3vectors_vector_bucket` and
`aws_s3vectors_index` resources, and `aws_bedrockagent_knowledge_base` accepts
`S3_VECTORS`. It has no continuously running cluster and is a better cost/operations
fit for a small demo than OpenSearch Serverless or Aurora PostgreSQL.

Rejected:

- OpenSearch Serverless: supported and capable, but its baseline capacity is
  disproportionate to a tiny demo.
- Aurora PostgreSQL/pgvector: adds database lifecycle and baseline capacity.
- Managed OpenSearch: continuously running cluster.
- Third-party Pinecone/Redis/MongoDB: credentials and another vendor are unnecessary.

Known S3 Vectors constraints accepted here: semantic search only, float vectors,
metadata limits, and eventual ingestion consistency.

## RAG API: RetrieveAndGenerate

Use the managed API to reduce code and obtain native citations. The prompt requires
grounded answers and an explicit insufficiency response. Conversation continuity is
owned by DynamoDB and a bounded history prefix; Bedrock runtime session IDs are not
the system of record.

## Encryption

Use AWS-managed service encryption for S3 objects, DynamoDB, Lambda artifacts, and
logs where that is the simple default. Use an AWS-managed KMS key for SNS where
supported. Avoid customer-managed keys by default because per-key monthly cost and
expanded policies are material for this demo. The pre-existing state bucket must
already have versioning, public blocking, and encryption; it is intentionally out of
scope for the root module.

## Terraform

- CLI: 1.15.8 exactly in GitHub Actions; configuration permits `~> 1.15.0`.
- AWS provider: `~> 6.55.0`. CI captures the generated dependency lockfile in each
  immutable plan artifact; commit the lockfile after the first successful trusted
  initialization when the provider is reachable.
- Backend: partial S3 backend with `use_lockfile = true`.
- Legacy DynamoDB state locking is documented as deprecated and can be inserted in
  an environment backend file only if an assignment environment mandates it.

## Frontend and citations

Plain HTML/CSS/JavaScript keeps the application small. Citations display a sanitized
object filename and excerpt; private S3 URLs are deliberately not exposed or
presigned because direct document download is not necessary to demonstrate RAG.

## Source references

- AWS: S3 Vectors with Bedrock Knowledge Bases:
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-bedrock-kb.html
- AWS: S3 Vectors Regions:
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-regions-quotas.html
- AWS: supported Knowledge Base embedding models:
  https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-supported.html
- AWS: Nova Micro:
  https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-nova-micro.html
- Terraform AWS Knowledge Base resource:
  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_knowledge_base
- Terraform S3 backend locking:
  https://developer.hashicorp.com/terraform/language/backend/s3
