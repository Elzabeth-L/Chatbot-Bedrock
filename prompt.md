Act as a senior AWS cloud architect, DevOps engineer, Terraform engineer, Python backend developer, and GitHub Actions specialist.

Design and implement a complete but intentionally simple Retrieval-Augmented Generation chatbot using Amazon Bedrock, Amazon Bedrock Knowledge Bases, Terraform, and GitHub Actions.

The primary objective is to demonstrate:

* Amazon Bedrock RAG integration
* Secure AWS infrastructure
* Terraform Infrastructure as Code
* Automated knowledge-base ingestion
* Session-based conversation history
* GitHub Actions CI/CD using AWS OIDC
* Remote Terraform state management
* Least-privilege IAM
* Monitoring and cost controls

The application itself must remain minimal. Do not add unnecessary production-scale features.

# 1. Application requirements

Build a simple browser-based chatbot that answers questions using documents stored in an Amazon Bedrock Knowledge Base.

Use a small collection of official technical documentation as the chatbot’s knowledge source. Terraform or Kubernetes documentation may be used. Include a small set of sample source documents in the repository so that the application can be demonstrated immediately.

The application must support the following flow:

1. A user opens the chatbot frontend.
2. The browser creates a unique session ID when no session ID exists.
3. The session ID is retained in browser local storage.
4. The user submits a question.
5. The frontend sends the question and session ID to an API Gateway HTTP API.
6. API Gateway invokes a query-handling Lambda function.
7. The Lambda loads the existing conversation history for that session from DynamoDB.
8. The Lambda queries the Bedrock Knowledge Base using `RetrieveAndGenerate`, or an equivalent `Retrieve` followed by model invocation if that produces a better implementation.
9. The model generates an answer grounded in the retrieved documents.
10. The Lambda saves the user message and assistant response in DynamoDB.
11. The API returns the answer and citations.
12. The frontend displays the answer and its source citations.

No user registration or login is required.

Conversation history is session-based, not user-account-based.

The chatbot must:

* Accept text questions.
* Return answers grounded in the knowledge base.
* Return source citations whenever retrieval sources are available.
* Preserve conversation context within the same browser session ID.
* Restore available session history when the page is refreshed.
* Start a new conversation when the user selects “New chat.”
* Handle missing, expired, or unknown session IDs safely.
* Return a clear response when the knowledge base does not contain enough information.
* Avoid fabricating answers when relevant source material is unavailable.

Implement a minimal frontend using either plain HTML, CSS, and JavaScript or another lightweight approach that does not introduce unnecessary complexity.

The frontend only needs:

* A chatbot title.
* A scrollable conversation area.
* A text input.
* A Send button.
* A New Chat button.
* Basic loading and error states.
* Citation links or citation labels under assistant responses.

Do not implement:

* User authentication
* Amazon Cognito
* User profiles
* WebSockets
* Streaming responses
* File upload through the frontend
* An administrative dashboard
* ECS
* EKS
* Amplify
* Step Functions
* A complex frontend framework unless there is a strong technical reason

# 2. Model selection

This is a text-only RAG chatbot.

Prefer a low-cost Amazon-native model.

Evaluate models in the following order:

1. Amazon Nova Micro
2. Amazon Nova Lite
3. Another low-cost Bedrock text model only when neither is compatible with the selected Region and Knowledge Base query flow

Prefer Amazon Titan Text Embeddings V2 for document embeddings unless another supported model provides a clear compatibility or cost advantage.

Before selecting the Region and model IDs, verify:

* Current Amazon Bedrock regional availability
* Knowledge Base compatibility
* `RetrieveAndGenerate` compatibility
* Embedding-model compatibility
* Whether direct model IDs or inference-profile ARNs are required
* Terraform AWS provider support

Do not assume that a model is available in every Region.

The final selected generation model ID and embedding model ID must be configurable through Terraform variables.

# 3. Cost requirements

This project will run in a Free Tier or low-budget AWS account.

AWS promotional credits may be available, but do not assume that Amazon Bedrock, model inference, vector storage, or knowledge-base ingestion are permanently free.

Optimize for the lowest reasonable cost while satisfying the task.

For the vector store:

* Evaluate Amazon S3 Vectors first because this is a small demonstration project.
* Use it when it is supported by Amazon Bedrock Knowledge Bases, the selected Region, and the Terraform AWS provider.
* If S3 Vectors cannot be implemented reliably through Terraform, select another supported vector store.
* Document the selected vector store, expected cost behavior, reason for selecting it, and rejected alternatives.
* Avoid selecting an expensive continuously running vector-store architecture without justification.

Use cost-conscious defaults such as:

* API Gateway HTTP API rather than REST API
* DynamoDB on-demand capacity unless provisioned capacity has a clear advantage
* Short CloudWatch log retention
* Modest Lambda memory and timeout settings
* CloudFront Price Class 100 where appropriate
* Small source-document corpus
* Conservative model token limits
* No provisioned Bedrock throughput
* No NAT Gateway unless absolutely required
* No unnecessary VPC attachment for Lambda

Create an AWS Budget with an SNS alert. This is mandatory.

The monthly budget threshold must be configurable through Terraform variables.

Use a sensible demonstration default, such as USD 10 per month, but do not hardcode the value throughout the project.

# 4. Source-document storage

Create a private S3 bucket for the Bedrock Knowledge Base source documents.

The bucket must have:

* S3 Block Public Access enabled
* Versioning enabled
* Encryption at rest
* Secure transport enforcement
* Bucket-owner-enforced object ownership
* Lifecycle or retention decisions documented
* No public bucket policy

Use a dedicated prefix such as:

`knowledge-base/documents/`

The sample documents must be uploaded through Terraform or a clearly documented deployment step.

Changes to unrelated objects outside the knowledge-base document prefix must not trigger ingestion.

# 5. Bedrock Knowledge Base

Create an Amazon Bedrock Knowledge Base backed by the private S3 document bucket.

The Knowledge Base configuration must include:

* The selected embedding model
* The selected vector store
* The S3 data source
* A suitable text chunking strategy
* A least-privilege Bedrock Knowledge Base service role

Choose a reasonable chunking strategy for technical documentation and explain the decision in the README.

The Bedrock Knowledge Base role must only be able to access the required:

* Source S3 bucket and prefix
* Embedding model
* Vector-store resources
* Required Bedrock actions

Do not use broad wildcard permissions when resource-level scoping is supported.

# 6. Automatic ingestion

Implement automatic knowledge-base synchronization when supported source documents are created, updated, or removed from S3.

A suitable flow may be:

S3 event → EventBridge or SQS → ingestion Lambda → Bedrock `StartIngestionJob`

The exact implementation is an architectural decision, but it must be reliable and must not require a person to press “Sync.”

The ingestion implementation must:

* React only to the intended S3 bucket and document prefix.
* Handle new and updated documents.
* Account for deleted documents when supported by the chosen synchronization mechanism.
* Avoid starting excessive duplicate ingestion jobs when several objects are uploaded together.
* Handle the fact that only one ingestion job may be allowed to run at a time.
* Handle transient failures and retries.
* Log the ingestion job ID and status.
* Use a dead-letter mechanism or failure destination where appropriate.
* Use a dedicated least-privilege IAM role.
* Avoid recursive triggers.
* Document ingestion timing and eventual consistency.

Do not silently ignore failed ingestion jobs.

# 7. Query Lambda

Create a Python query-handling Lambda.

Use a currently supported Python runtime.

The Lambda must:

* Accept an API request containing `sessionId` and `message`.
* Validate the request body.
* Validate reasonable maximum input lengths.
* Load prior session messages from DynamoDB.
* Limit the amount of history included in the model request.
* Call the Bedrock Knowledge Base.
* Return the generated answer.
* Extract and return citation information.
* Save the current user and assistant messages to DynamoDB.
* Return structured JSON responses.
* Use environment variables for deployed configuration.
* Log structured operational information without logging sensitive content unnecessarily.
* Handle throttling, timeouts, invalid requests, Bedrock errors, and empty retrieval results.
* Use an appropriate Lambda timeout for Bedrock inference.
* Reuse AWS SDK clients outside the handler.
* Include unit tests for core request validation and response transformation logic.

Use a response structure similar to:

```json
{
  "sessionId": "generated-or-existing-session-id",
  "answer": "Generated answer",
  "citations": [
    {
      "title": "Document title or object name",
      "uri": "source-location-when-available",
      "excerpt": "Relevant source excerpt"
    }
  ]
}
```

Do not expose private raw S3 object URLs that a browser cannot access.

For citation access, either:

* Display human-readable S3 object names and excerpts, or
* Generate short-lived presigned URLs only when this is secure and useful

Explain the selected approach.

# 8. Session history in DynamoDB

Store per-session conversation history in DynamoDB.

No login or user identity system is required.

Choose and document an appropriate table design. A recommended pattern is:

* Partition key: `session_id`
* Sort key: `created_at` or a sortable message identifier
* Attributes:

  * `role`
  * `content`
  * `citations`
  * `created_at`
  * `expires_at`

Configure DynamoDB TTL using the `expires_at` attribute.

Make the session retention period configurable through Terraform.

Use a reasonable default such as 24 hours or 7 days.

The implementation must:

* Extend or calculate TTL consistently for session records.
* Query messages in chronological order.
* Limit the number of history messages read for each request.
* Avoid DynamoDB scans.
* Use consistent data types.
* Return existing history through a dedicated API route or as part of the initial frontend flow.
* Allow a new session to be started without deleting unrelated sessions.

Suggested API routes:

* `POST /chat`
* `GET /sessions/{sessionId}/messages`

A separate delete endpoint is optional and should only be added when it remains simple.

Use DynamoDB on-demand billing unless another mode is justified.

# 9. API Gateway

Expose the backend through an API Gateway HTTP API.

Configure:

* Lambda integration
* Required routes
* CORS restricted to the deployed CloudFront frontend origin
* Access logging
* Appropriate throttling where supported
* Structured error responses
* No unauthenticated administrative routes

The API does not require user authentication because this is a simple demonstration application.

However, acknowledge in the README that a public unauthenticated API can be abused and explain which controls limit cost and misuse, such as:

* API throttling
* Input length limits
* Model output-token limits
* AWS Budget alerts
* CloudWatch alarms
* Optional AWS WAF as a documented production enhancement, not necessarily part of this implementation

Output the API Gateway invoke URL.

# 10. SSM Parameter Store

Store or reference the selected Bedrock generation model identifier and Knowledge Base ID through AWS Systems Manager Parameter Store.

The application code must not hardcode either value.

The task specifically requires the model ID and Knowledge Base ID to be read from SSM Parameter Store at deployment time.

Implement this so that Terraform resolves the parameter values during deployment and injects the resolved values into the Lambda environment variables.

The query Lambda should not make an SSM API call for every chat request unless there is a documented technical reason.

Clearly distinguish:

* Terraform-managed SSM parameters
* Terraform deployment-time resolution
* Lambda runtime environment variables

Avoid exposing unnecessary values as sensitive Terraform outputs.

# 11. Frontend hosting

Create a separate private S3 bucket for the static frontend.

Configure:

* S3 Block Public Access
* Encryption at rest
* Secure transport enforcement
* No public website hosting
* CloudFront distribution
* CloudFront Origin Access Control
* HTTPS-only viewer policy
* Default root object
* Suitable cache behavior
* SPA or error-response handling if needed
* Security-related response headers where practical

The frontend S3 bucket must be accessible only through CloudFront.

Inject or configure the deployed API URL into the frontend without manually editing source files after deployment.

Output the CloudFront domain name.

# 12. IAM security

Every Lambda must have a separate IAM execution role unless role sharing is explicitly justified.

Scope each role to only the actions and resources it requires.

Examples include:

Query Lambda:

* Required Bedrock Agent Runtime retrieval/generation action
* Read and write access to the specific DynamoDB table
* CloudWatch Logs permissions
* Optional S3 presigning permissions only if citations use presigned URLs

Ingestion Lambda:

* Required Bedrock ingestion action
* Permissions to access only the relevant Knowledge Base or data source
* CloudWatch Logs permissions
* Queue or EventBridge permissions when applicable

Bedrock Knowledge Base service role:

* Read access to the document bucket and required prefix
* Embedding model invocation
* Required vector-store access

Do not use:

* `Action = "*"`
* `Resource = "*"` when the AWS API supports narrower resource scoping
* AdministratorAccess
* Broad S3 permissions
* Broad Bedrock permissions

When an AWS action does not support resource-level permissions and requires `"Resource": "*"`, document that specific AWS limitation in code comments and in the README. Do not treat that as permission to use wildcard actions.

# 13. Encryption and security

Encrypt supported resources at rest.

Use either AWS-managed keys or customer-managed KMS keys based on the best balance of security, complexity, and cost for this demonstration.

Document the choice.

At minimum, secure:

* Source-document S3 bucket
* Frontend S3 bucket
* DynamoDB table
* SNS topic where applicable
* CloudWatch Logs where practical
* Terraform remote state bucket

Do not expose secrets in:

* Terraform outputs
* GitHub Actions logs
* Lambda logs
* Repository files
* Frontend JavaScript

The application should not require application secrets for normal operation.

# 14. Monitoring

Create CloudWatch alarms for:

1. Query Lambda error rate
2. Ingestion Lambda failures
3. API Gateway HTTP API 5xx rate
4. DynamoDB throttled requests

The task explicitly requires alarms for Lambda error rate, API Gateway 5xx rate, and DynamoDB throttled requests.

Use metric math where needed to calculate an actual Lambda error percentage rather than alarming only on a raw error count.

Make alarm thresholds configurable.

Connect alarms to an SNS topic.

Allow an optional alert email address to be supplied through Terraform variables.

Do not hardcode an email address.

Document that email subscriptions require confirmation.

Set a cost-conscious CloudWatch log-retention period.

# 15. AWS Budget

Create an AWS Budget using Terraform.

Requirements:

* Monthly cost budget
* Configurable budget amount
* SNS alert integration
* At least one actual-spend threshold
* Optional forecasted-spend threshold when supported cleanly
* Clear documentation of SNS subscription confirmation
* No assumption that a budget automatically stops resources

The budget alert must be part of the main deployment and must not be optional.

# 16. Terraform requirements

Use Terraform for all infrastructure that is supported reliably by the AWS provider.

Use a recent stable Terraform version and AWS provider version.

Structure the Terraform code cleanly. The exact module boundaries are an architectural decision, but the project should remain understandable and avoid excessive abstraction.

Possible areas include:

* Storage
* Bedrock Knowledge Base
* Vector store
* Ingestion
* Chat API
* Session storage
* Frontend and CloudFront
* Monitoring
* Budget
* IAM

Use:

* Variables
* Outputs
* Locals
* Data sources
* Explicit dependencies only when necessary
* Resource tags
* Input validation
* Terraform formatting
* Provider version constraints
* Terraform version constraints

Avoid:

* Hardcoded account IDs
* Hardcoded Regions
* Hardcoded ARNs
* Hardcoded Knowledge Base IDs
* Hardcoded model IDs in application code
* Unnecessary `null_resource` or local-exec usage
* Excessive modules for individual resources
* Circular dependencies

Run and pass:

* `terraform fmt -check`
* `terraform init`
* `terraform validate`
* `terraform plan`

Add linting or security scanning when practical, such as:

* TFLint
* Checkov or Trivy configuration scanning

Do not allow scanning tools to obscure the central task with excessive configuration.

# 17. Terraform remote state

Store Terraform state remotely in the existing shared Terraform-state S3 bucket.

Do not create the shared backend bucket in the same root module that uses it.

Support state locking using the currently recommended S3 backend locking mechanism for the selected Terraform version.

If the assignment environment specifically requires a DynamoDB lock table, support it as a configurable legacy-compatible option and explain the decision.

The backend configuration must be supplied through backend configuration files or workflow inputs because Terraform backend blocks cannot use ordinary Terraform variables.

Do not commit environment-specific backend secrets.

Provide an example backend configuration file such as:

`backend.hcl.example`

Include placeholders for:

* State bucket name
* State key
* AWS Region
* Locking configuration

# 18. GitHub Actions AWS authentication

Use GitHub Actions OIDC to authenticate to AWS.

An existing IAM role will be supplied.

Do not:

* Create long-lived AWS access keys
* Store AWS access keys in GitHub Secrets
* Create a new OIDC provider unless explicitly required
* Create a new deployment role unless explicitly requested

Use configurable GitHub variables or secrets for non-secret deployment configuration such as:

* AWS role ARN
* AWS Region
* Terraform backend bucket
* Terraform state key
* Terraform variable-file selection

The GitHub workflow must request only the permissions it actually needs.

OIDC authentication requires:

```yaml
permissions:
  id-token: write
  contents: read
```

PR commenting may also require:

```yaml
pull-requests: write
```

Scope the GitHub OIDC trust policy recommendations to the intended repository, branch, environment, and event types.

Document the required trust-policy conditions for the existing AWS IAM role.

# 19. GitHub Actions workflow

Create a GitHub Actions workflow supporting:

* Pull-request plan
* Manual plan
* Manual apply
* Manual destroy

Use `workflow_dispatch` with an action selector:

* `plan`
* `apply`
* `destroy`

Automatic pull-request execution must perform plan only.

The pull-request workflow must:

1. Check out the repository.
2. Configure AWS credentials through OIDC.
3. Install the required Terraform version.
4. Run formatting checks.
5. Initialize Terraform with the remote backend.
6. Validate Terraform.
7. Run the selected linting or security checks.
8. Create a binary Terraform plan file.
9. Create a human-readable plan.
10. Upload the binary plan and required metadata as an artifact.
11. Post or update a readable summary on the pull request.
12. Avoid posting duplicate plan comments on every rerun.
13. Sanitize or limit plan output when necessary.
14. Fail clearly when planning fails.

The plan must be reviewable directly from the pull request and not only from workflow logs.

A concise plan summary may be posted in the PR comment, with the full text available as an artifact or job summary when GitHub comment-size limits are reached.

# 20. Apply the reviewed plan artifact

The apply operation must apply the exact binary Terraform plan artifact that was reviewed.

Do not run a fresh `terraform plan` immediately before apply and then claim that it is the reviewed plan.

Design a secure artifact-promotion process.

The plan artifact must be associated with immutable metadata, including:

* Git commit SHA
* Pull-request number or source workflow run ID
* Terraform version
* Provider lock file
* Terraform working directory
* Backend configuration identity
* Variable-file identity
* Plan creation timestamp
* SHA-256 checksum of the binary plan

Before apply, verify:

* The artifact checksum
* The current commit SHA matches the planned commit
* The Terraform version matches
* The dependency lock file matches
* The backend and environment match
* The artifact comes from an authorized workflow run
* The artifact has not expired
* The plan was created from the intended branch or pull request

Because Terraform binary plans are not portable across arbitrary environments, ensure that plan and apply use compatible:

* Operating system
* CPU architecture
* Terraform version
* Provider versions
* Working directory
* Configuration commit

Use GitHub Environments and required reviewers for apply when available.

Document any GitHub plan-artifact retention limitations.

Do not permit applying untrusted plan artifacts from forked pull requests.

If a fully automatic PR-plan-to-later-manual-apply workflow cannot safely satisfy GitHub artifact and approval constraints, implement the safest practical design and clearly document the limitation rather than silently generating a new plan.

# 21. Destroy workflow

Destroy must:

* Be manual only.
* Require explicit confirmation input.
* Use a protected GitHub Environment when available.
* Clearly display the target environment.
* Prevent accidental execution from pull requests.
* Run only after the user enters an exact confirmation value such as `destroy`.
* Preserve logs and outputs needed to verify cleanup.

Because `terraform destroy` normally generates its own destroy plan, use a two-stage reviewed destroy-plan process where practical:

1. Generate and upload a destroy plan.
2. Require approval.
3. Apply the exact reviewed destroy-plan artifact.

Do not make destructive behavior automatic.

# 22. Repository structure

Choose a clean repository structure suitable for a small infrastructure-focused project.

A possible structure is:

```text
.
├── .github/
│   └── workflows/
├── frontend/
│   ├── index.html
│   ├── styles.css
│   └── app.js
├── lambdas/
│   ├── chat/
│   └── ingestion/
├── documents/
├── terraform/
│   ├── modules/
│   ├── environments/
│   ├── backend.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── main.tf
├── tests/
├── backend.hcl.example
├── terraform.tfvars.example
├── .gitignore
└── README.md
```

This is guidance, not a mandatory structure. Change it where a better organization is justified.

# 23. Terraform outputs

Output at least:

* API Gateway invoke URL
* CloudFront domain name
* Knowledge Base ID
* Knowledge Base data source ID
* DynamoDB table name
* Source-document bucket name
* Frontend bucket name
* Selected generation model identifier
* Selected embedding model identifier
* SNS alert topic ARN
* Budget name

Mark outputs as sensitive only when genuinely necessary.

# 24. Documentation

Create a detailed README containing:

* Project overview
* Application behavior
* Architecture diagram using Mermaid
* Request flow
* Ingestion flow
* Conversation-history flow
* Repository structure
* AWS service selection and justification
* Selected Region and model compatibility
* Vector-store decision
* Security decisions
* IAM design
* Cost considerations
* Estimated cost drivers
* AWS Free Tier and credit warning
* Prerequisites
* Required Bedrock model access or activation steps
* Required GitHub repository variables and secrets
* Existing AWS OIDC role trust-policy requirements
* Terraform backend setup
* Local Terraform commands
* GitHub Actions plan, apply, and destroy procedures
* How reviewed plan artifacts are promoted
* Deployment steps
* How to upload or update source documents
* How automatic ingestion works
* How session TTL works
* Testing instructions
* CloudWatch alarms
* AWS Budget behavior
* SNS email-confirmation requirement
* Troubleshooting
* Cleanup instructions
* Known limitations
* Production-hardening recommendations

Include a warning explaining that:

* Bedrock usage is billed based on usage.
* Promotional AWS credits can expire.
* Vector-store resources may continue to incur charges while deployed.
* AWS Budgets send alerts but do not automatically stop spending.
* The user should destroy the demonstration environment when it is no longer required.

# 25. Tests and validation

Include practical tests for:

* Query Lambda request validation
* DynamoDB message transformation
* Citation extraction
* TTL generation
* Invalid session ID handling
* Empty retrieval response handling
* Frontend API error handling where practical
* Terraform formatting and validation

Provide a smoke-test script or documented commands that verify:

* The frontend is reachable through CloudFront.
* The API health or chat route is reachable.
* A question returns an answer.
* Citations are included.
* Session history persists across requests.
* A new session does not receive another session’s history.
* Updated documents trigger a new ingestion job.
* Terraform outputs are produced correctly.

# 26. Implementation approach

Do not immediately generate the entire repository without first reasoning through the architecture.

Proceed in this order:

1. Inspect the existing repository.
2. Identify existing files and constraints.
3. Check current AWS provider support for the required Bedrock and vector-store resources.
4. Present a concise implementation plan.
5. Present the selected architecture and request flows.
6. Present the model, Region, embedding model, and vector-store decision with justification.
7. Present the intended repository structure.
8. Present the IAM responsibility matrix.
9. Identify assumptions, cost risks, and provider limitations.
10. Implement the solution in logical stages.
11. Run formatting, validation, tests, and static analysis.
12. Correct all errors that can be corrected locally.
13. Provide a final summary of created files, validation results, required manual steps, and remaining limitations.

Do not ask for architectural decisions that can reasonably be selected from these requirements.

Make the best architectural decision based on:

* Correctness
* Security
* Current AWS support
* Low cost
* Terraform compatibility
* Operational simplicity
* Assignment compliance

Ask for clarification only when a genuinely required external value is missing, such as:

* Existing Terraform-state bucket name
* Existing AWS deployment role ARN
* GitHub organization and repository name
* AWS Region constraint
* SNS notification email

When these values are not yet available, use clearly named variables and placeholders rather than blocking the rest of the implementation.

# 27. Definition of done

The project is complete only when:

* Terraform provisions the required AWS architecture.
* The source and frontend buckets are private.
* The Knowledge Base can ingest the supplied documents.
* New or updated source documents initiate automatic synchronization.
* The chatbot returns grounded answers with citations.
* Conversation history persists by session ID without requiring login.
* DynamoDB TTL is configured and used.
* API Gateway exposes the query Lambda.
* CloudFront serves the frontend.
* Model and Knowledge Base identifiers are not hardcoded in application code.
* Lambda IAM policies follow least privilege.
* Required CloudWatch alarms exist.
* The mandatory AWS Budget and SNS alert exist.
* Terraform uses remote state and locking.
* GitHub Actions authenticates through OIDC without stored AWS keys.
* Pull requests generate reviewable plans.
* Apply uses the exact reviewed binary plan artifact.
* Destroy is manual and protected.
* API Gateway and CloudFront URLs are Terraform outputs.
* The README documents deployment, operation, costs, and cleanup.
* Formatting, validation, and available tests pass.

Keep the implementation focused. This is a simple RAG chatbot and an infrastructure automation exercise, not a production SaaS platform.
