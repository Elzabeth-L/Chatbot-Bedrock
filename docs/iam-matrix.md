# IAM responsibility matrix

| Principal | Allowed responsibilities | Primary resource scope |
|---|---|---|
| Query Lambda role | `bedrock:RetrieveAndGenerate`; query/put DynamoDB messages; write its logs | One Knowledge Base ARN where supported, one table/index scope, one log group |
| Ingestion Lambda role | list/start ingestion jobs; receive/delete SQS messages; write its logs | One Knowledge Base and data source, one queue, one log group |
| Bedrock Knowledge Base role | read source bucket/prefix; invoke Titan embedding model; read/write/query/delete vectors | One S3 bucket/prefix, one embedding model ARN, one vector index ARN |
| API Gateway service | invoke query Lambda through Lambda resource policy; write access logs | One Lambda alias/function and one log group |
| S3 notification service | send object event messages | One SQS queue, constrained by source bucket ARN/account |
| CloudFront service | read frontend objects through OAC | One frontend bucket and distribution source ARN |
| AWS Budgets service | publish alerts | One SNS topic, with account/source constraints when supported |
| CloudWatch alarms | publish alarm transitions | One SNS topic |
| Existing GitHub deployment role | remote state access and resource deployment | Existing externally managed role, scoped to repository/environment |

## Wildcard policy exceptions

No wildcard actions are allowed. `bedrock:RetrieveAndGenerate` currently does not
support resource-level authorization, so the query role uses `Resource: "*"` for
that one exact action. The runtime is constrained to the Terraform-injected
Knowledge Base ID, and model invocation is separately scoped to the selected model
ARN.

If provider/API testing finds another action requires a resource wildcard, it must:

1. list only the exact actions,
2. add applicable account/Region/SourceArn conditions,
3. contain an inline comment in Terraform, and
4. be documented in the root README.

The implementation must not broaden unrelated statements to compensate for such an
exception.
