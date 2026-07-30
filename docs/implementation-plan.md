# Implementation plan

## Goal

Build a deliberately small, low-cost browser RAG chatbot using Amazon Bedrock
Knowledge Bases, S3 Vectors, Lambda, API Gateway HTTP API, DynamoDB, private S3,
CloudFront, Terraform, and GitHub Actions OIDC.

## Acceptance strategy

Implementation is complete only when the repository contains the infrastructure,
two tested Python Lambda functions, the static frontend, sample documents,
deployment automation, operational controls, and complete operator documentation.
Local checks must pass. Cloud-dependent checks that cannot run without an AWS
account must be identified explicitly.

## Stages

### 1. Repository foundation

- Create the agreed directories, `.gitignore`, examples, and developer tooling.
- Pin Terraform CLI 1.15.8 and AWS provider 6.55.x.
- Add a partial S3 backend plus `backend.hcl.example` using native S3 lockfiles.
- Establish project naming, tags, validated variables, and provider data sources.

Exit: Terraform root configuration parses and all later files have stable locations.

### 2. Application code and tests

- Implement a Python 3.13 chat Lambda with small pure functions for validation,
  history transformation, TTL generation, and citation extraction.
- Implement `POST /chat` and `GET /sessions/{sessionId}/messages` behavior in one
  handler, with bounded history and structured errors.
- Use `RetrieveAndGenerate`; pass a bounded, formatted conversation context within
  the current question instead of relying on an opaque Bedrock session.
- Implement the ingestion Lambda. It consumes batched SQS S3 notifications, starts
  one incremental sync, and retries when a sync is already active.
- Add unit tests with mocked AWS boundaries.

Exit: Python tests and static syntax checks pass without AWS credentials.

### 3. Data and knowledge-base infrastructure

- Create private, versioned, encrypted source-document storage with public access
  blocked, bucket-owner-enforced ownership, TLS enforcement, and a documented
  noncurrent-version lifecycle.
- Upload only repository files under `documents/` to
  `knowledge-base/documents/`.
- Create a dedicated S3 vector bucket and 256-dimension float32 vector index.
- Create the Bedrock Knowledge Base, Titan Text Embeddings V2 configuration, fixed
  chunking, S3 data source, and least-privilege service role.
- Store the configurable generation model identifier and generated Knowledge Base
  ID in Terraform-managed SSM parameters, resolve them through Terraform data
  sources, and inject the resolved values into the Lambda environment.

Exit: resource graph supports first deployment and initial ingestion.

### 4. Session API and automatic ingestion

- Create an on-demand DynamoDB table keyed by `session_id` and sortable `message_id`,
  with `expires_at` TTL and point-in-time recovery disabled by default for cost.
- Package and deploy each Lambda with a separate execution role and log group.
- Connect S3 object create/delete events for the intended prefix to SQS, configure a
  batching window, partial batch failure, retry delay, and DLQ.
- Create API Gateway HTTP API routes, Lambda integration, access logs, CORS, and
  stage throttling.

Exit: chat/history routes and eventual document synchronization are wired.

### 5. Frontend and edge delivery

- Build plain HTML/CSS/JavaScript supporting local-storage session IDs, history
  restoration, new chat, loading/error states, and citation labels/excerpts.
- Render the deployed API URL from a Terraform template; never place secrets in JS.
- Create a separate private encrypted S3 bucket, CloudFront OAC, HTTPS redirect,
  response security headers, Price Class 100, and restricted bucket policy.

Exit: CloudFront serves the application and calls only the deployed API.

### 6. Operations, security, and cost controls

- Add structured log groups with short retention.
- Add Lambda error-rate metric math alarms, ingestion failure alarm, API 5xx alarm,
  DynamoDB throttling alarm, and a shared encrypted SNS topic.
- Create the mandatory configurable monthly AWS Budget and actual/forecast alerts.
- Add an optional email subscription and document confirmation.
- Review all policies for narrow actions/resources and annotate unavoidable
  resource wildcards.

Exit: mandatory monitoring, alerts, and budget resources exist.

### 7. CI/CD and artifact promotion

- Maintain exactly two top-level workflows:
  - Application CI performs tests, SAST, SCA, SonarCloud, and Snyk gates for the
    Python Lambda source and static browser application.
  - Terraform CI performs PR/manual plans and exact reviewed-plan promotion.
- Keep Terraform workflow YAML declarative: move command logic into repository-local
  composite actions; do not embed `run` or `script` blocks in the top-level workflow.
- Use PR/manual plan execution with GitHub OIDC and only `id-token: write`,
  `contents: read`, and PR comment permission when needed.
- Produce a binary plan, readable summary, lockfile, and immutable metadata with
  SHA-256 checksums.
- Add a protected manual apply path that downloads a selected trusted plan-run
  artifact and verifies commit, versions, working directory, backend identity,
  variable identity, age, checksums, repository, event, and branch before applying
  the exact binary plan.
- Add a protected, explicit two-stage destroy-plan/destroy-apply process.
- Refuse fork-originated plan promotion.

Exit: apply never substitutes a freshly generated plan for the reviewed artifact.

### Application security and deployment packaging

- Keep deployment aligned with the actual Terraform architecture:
  - Terraform packages each Python Lambda as a ZIP archive and deploys it directly.
  - Terraform uploads the plain HTML, CSS, JavaScript, and rendered API configuration
    to the private frontend S3 bucket served by CloudFront.
- Maintain only the ZIP and static-file formats used by Terraform deployment.
- Run Ruff and pytest with coverage.
- Run CodeQL SAST for Python and JavaScript, GitHub dependency review on pull
  requests, Snyk Open Source SCA and Snyk Code SAST, plus SonarCloud analysis and
  its quality gate.
- Upload SARIF where GitHub code scanning is enabled.
- Reference `SNYK_TOKEN` and `SONAR_TOKEN` only through GitHub Secrets.

Exit: CI analyzes the exact source deployed by Terraform without maintaining an
unused second delivery path.

### 8. Documentation and verification

- Write the root README with deployment, security, costs, flows, OIDC trust policy,
  artifact promotion, ingestion behavior, tests, troubleshooting, and cleanup.
- Add smoke-test commands/script.
- Run `terraform fmt -check`, offline-capable `terraform validate` after init,
  Python unit tests, frontend checks where practical, and configuration scanning.
- Correct all locally reproducible errors and list checks blocked by credentials or
  missing external values.

Exit: definition-of-done checklist is traceable to code and test evidence.

## External values

These do not block implementation. Examples will use placeholders:

- Existing Terraform backend bucket name
- Existing AWS deployment role ARN
- GitHub owner/repository
- Optional notification email

The default deployment Region is `us-east-1`; it remains configurable but changing
it requires revalidating Bedrock, model, and S3 Vectors compatibility.
