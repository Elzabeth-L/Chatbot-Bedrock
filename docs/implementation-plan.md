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
- Add a separate `bootstrap/` Terraform root and run it locally, never through the
  application pipeline. It owns the dedicated remote-state S3 bucket, versioning,
  default encryption, bucket-owner-enforced ownership, public-access blocking, and
  TLS-only bucket policy.
- When the named bucket already exists from an earlier manual bootstrap, adopt it
  with `terraform import` instead of deleting/recreating a globally unique bucket;
  all later changes must be made through the bootstrap Terraform root.
- Establish project naming, tags, validated variables, and provider data sources.

Exit: Terraform root configuration parses and all later files have stable locations.

### 2. Application code and tests

- Implement a Python 3.13 chat Lambda with small pure functions for validation,
  history transformation, TTL generation, and citation extraction.
- Implement `POST /chat` and `GET /sessions/{sessionId}/messages` behavior in one
  handler, with bounded history and structured errors.
- Use `RetrieveAndGenerate`; pass a bounded, formatted conversation context within
  the current question instead of relying on an opaque Bedrock session.
- Use a custom Bedrock generation prompt containing the required search-result and
  citation-format placeholders. Require every factual claim to be supported by the
  retrieved chunks and return one exact insufficiency response otherwise.
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
  batching window, partial batch failure, retry delay, and DLQ. Use account-level
  unreserved Lambda concurrency so deployment also works in new or quota-restricted
  AWS accounts where a reservation would violate Lambda's minimum unreserved pool.
- Create API Gateway HTTP API routes, Lambda integration, access logs, CORS, and
  stage throttling.

Exit: chat/history routes and eventual document synchronization are wired.

### 5. Frontend and edge delivery

- Build plain HTML/CSS/JavaScript supporting a browser-local session registry,
  selectable prior conversations, history restoration from DynamoDB, a new UUID on
  every New Chat action, loading/error states, and citation labels/excerpts.
- Present that registry as a compact persistent desktop sidebar with prompt-derived
  conversation titles, clear active/hover states, a centered reading column, and an
  accessible off-canvas sidebar on narrow screens.
- Keep session message content in DynamoDB; store only session IDs, display titles,
  and update timestamps in browser local storage. Treat the browser registry as a
  convenience index rather than cross-device identity or authorization.
- Render the deployed API URL from a Terraform template; never place secrets in JS.
- Publish the redesigned stylesheet under a new non-cached object key so CloudFront
  cannot combine a newly deployed HTML shell with a stale pre-sidebar stylesheet.
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
- Grant the chat Lambda the explicit resource-scoped `bedrock:Retrieve` permission
  required by the retrieval phase underlying `RetrieveAndGenerate`, while retaining
  the separate generation-model invocation permission.

Exit: mandatory monitoring, alerts, and budget resources exist.

### 7. CI/CD and artifact promotion

- Maintain exactly two top-level workflows:
  - Application CI reports every required check on every PR, but runs tests, SAST,
    SCA, SonarCloud, and Snyk only when application, test, dependency, or scan
    configuration paths change. On `main`, trigger it only for those relevant paths
    (with manual dispatch still available). Preserve both expanded CodeQL matrix
    check names on infra-only PRs while skipping their checkout and analysis steps.
  - Terraform CI performs plans for every same-repository PR, automatic plans after relevant pushes to
    `main`, manual plans, and exact reviewed-plan promotion.
- Keep Terraform workflow YAML declarative: move command logic into repository-local
  composite actions; do not embed `run` or `script` blocks in the top-level workflow.
- Run the required Terraform `plan` check on every same-repository PR so branch
  protection never waits indefinitely for a path-filtered required check.
- Use PR, main-push, and manual plan execution with GitHub OIDC and only `id-token: write`,
  `contents: read`, and PR comment permission when needed.
- Bootstrap separate repository-scoped GitHub OIDC roles: a read-oriented role for
  plan/refresh and backend locking, and a deployment role restricted to the
  protected `main` branch.
- Match exact immutable owner/repository IDs in OIDC subjects where GitHub's
  immutable subject format applies.
- Produce a binary plan, readable summary, lockfile, and immutable metadata with
  SHA-256 checksums.
- Explicitly include Terraform's hidden `.terraform.lock.hcl` in the reviewed-plan
  artifact so promotion can verify and restore the exact provider selections.
- Include the two Terraform-generated Lambda ZIP archives in the reviewed-plan
  artifact, record their SHA-256 checksums in immutable metadata, and verify and
  restore those exact archives before applying the binary plan.
- Manage supplemental role permissions in the local bootstrap root: give both the
  plan and deployment roles the Budget tag read required for state refresh, and
  give the deployment role exact backend state writes, Budget tag writes, DynamoDB
  TTL updates, and the CloudWatch Logs delivery operations required when API
  Gateway enables stage access logging.
- Recover a failed first apply declaratively by importing every resource confirmed
  as created before the backend write failure; exclude resources, such as the
  failed Budget creation, that a recovery plan verifies do not exist; never rerun
  against an empty state.
- Avoid IAM propagation races in the S3 Vectors bucket policy by using the account
  principal constrained to the exact Knowledge Base role through `aws:PrincipalArn`.
- Present one clear manual operation selector for change plan, reviewed apply,
  destruction plan, or reviewed destruction apply. Treat the explicit destructive
  selection as confirmation and keep apply operations restricted to `main`.
- Add a main-branch-only manual apply path that
  automatically selects the newest successful manual or main-push plan artifact
  for the exact commit and requested mode, and verifies commit, versions, working
  directory, backend identity,
  variable identity, age, checksums, repository, event, and branch before applying
  the exact binary plan.
- Print the complete HTTPS CloudFront frontend URL as a non-sensitive Terraform
  output and in the successful promotion log/summary so operators do not confuse
  it with the API Gateway invoke URL.
- Add a main-branch-only, explicitly selected two-stage destroy-plan/destroy-apply
  process.
- Refuse fork-originated plan promotion.

Exit: apply never substitutes a freshly generated plan for the reviewed artifact.

### Application security and deployment packaging

- Keep deployment aligned with the actual Terraform architecture:
  - Terraform packages each Python Lambda as a ZIP archive and deploys it directly.
  - Terraform uploads the plain HTML, CSS, JavaScript, and rendered API configuration
    to the private frontend S3 bucket served by CloudFront.
- Maintain only the ZIP and static-file formats used by Terraform deployment.
- Run Ruff and pytest with coverage.
- Run CodeQL SAST for Python and JavaScript, Snyk Open Source SCA and Snyk Code
  SAST, plus SonarCloud analysis and its quality gate.
- Keep the plain browser frontend in SonarCloud static analysis, but exclude it from
  coverage calculations until a JavaScript coverage harness exists; enforce imported
  pytest coverage for the Python Lambda code.
- Run SonarCloud at internal PR, manual, and main-push promotion points instead of
  duplicating unsupported feature-branch analysis.
- Select the intended Snyk organization explicitly through the non-sensitive
  `SNYK_ORG` GitHub Variable so CI does not depend on a user's preferred organization.
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

### 9. Enterprise solution design document

- Generate a formal Microsoft Word Solution Design Document from the implemented
  repository rather than from assumptions, covering application, AWS resources,
  Terraform, CI/CD, security, operations, deployment, cost, and maintenance.
- Include document control, an automatic table of contents, numbered headings,
  professional tables, headers/footers, page numbers, diagram placeholders or
  repository-derived diagrams, appendices, glossary, and clearly identified
  assumptions and non-implemented technologies.
- Verify time-sensitive AWS pricing against primary AWS sources, state the pricing
  date and estimation assumptions, and distinguish free-tier eligibility from
  estimated development and production usage.
- Validate the generated `.docx` package and inspect its extracted text/structure so
  the document can be opened and maintained without referring to source code.

Exit: a validated enterprise-formatted `.docx` is available under `docs/` as the
official architecture, implementation, deployment, and operations deliverable.

## External values

These do not block implementation. Examples will use placeholders:

- Bootstrapped Terraform backend bucket name
- GitHub plan and deployment role ARNs
- GitHub owner/repository
- Optional notification email

The default deployment Region is `us-east-1`; it remains configurable but changing
it requires revalidating Bedrock, model, and S3 Vectors compatibility.
