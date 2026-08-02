$ErrorActionPreference = "Stop"

# Public entry point. The Open XML implementation creates the same native Word
# document without relying on slow interactive Office automation. The repository-
# derived content template remains below and is consumed by that implementation.
& (Join-Path $PSScriptRoot "generate-sdd-openxml.ps1")
exit $LASTEXITCODE

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot "docs\Chatbot-Bedrock-Solution-Design-Document.docx"
$documentDate = "03 August 2026"
$version = "1.0"

$wdStyleNormal = -1
$wdStyleHeading1 = -2
$wdStyleHeading2 = -3
$wdStyleHeading3 = -4
$wdStyleTitle = -63
$wdStyleSubtitle = -75
$wdStyleCaption = -35
$wdPageBreak = 7
$wdAlignLeft = 0
$wdAlignCenter = 1
$wdAlignRight = 2
$wdCollapseEnd = 0
$wdFieldEmpty = -1
$wdFieldPage = 33
$wdAutoFitContent = 1
$wdBorderBottom = -3

$script:tableNumber = 0
$script:figureNumber = 0
$word = $null
$document = $null

function Set-CellText {
    param($Cell, [string]$Text, [bool]$Header = $false)
    $Cell.Range.Text = $Text
    if ($Header) {
        $Cell.Shading.BackgroundPatternColor = 0x5B3B1F
    }
}

function Add-Paragraph {
    param(
        [string]$Text,
        [bool]$Bold = $false,
        [bool]$Italic = $false,
        [int]$Alignment = 0,
        [int]$SpaceAfter = 7
    )
    $selection = $script:word.Selection
    $selection.Style = $script:document.Styles.Item($wdStyleNormal)
    $selection.ParagraphFormat.Alignment = $Alignment
    $selection.ParagraphFormat.SpaceAfter = $SpaceAfter
    $selection.Font.Bold = if ($Bold) { [int]1 } else { [int]0 }
    $selection.Font.Italic = if ($Italic) { [int]1 } else { [int]0 }
    $selection.TypeText($Text)
    $selection.TypeParagraph()
    $selection.Font.Bold = 0
    $selection.Font.Italic = 0
    $selection.ParagraphFormat.Alignment = $wdAlignLeft
}

function Add-Heading {
    param([int]$Level, [string]$Text)
    $selection = $script:word.Selection
    $style = switch ($Level) {
        1 { $wdStyleHeading1 }
        2 { $wdStyleHeading2 }
        default { $wdStyleHeading3 }
    }
    $selection.Style = $script:document.Styles.Item($style)
    $selection.TypeText($Text)
    $selection.TypeParagraph()
    if ($Level -eq 1) { Write-Output "section=$Text" }
}

function Add-Bullets {
    param([string[]]$Items)
    foreach ($item in $Items) {
        Add-Paragraph -Text ([char]0x2022 + "  " + $item) -SpaceAfter 3
    }
    Add-Paragraph -Text "" -SpaceAfter 2
}

function Add-NumberedSteps {
    param([string[]]$Items)
    for ($index = 0; $index -lt $Items.Count; $index++) {
        Add-Paragraph -Text ("{0}.  {1}" -f ($index + 1), $Items[$index]) -SpaceAfter 4
    }
    Add-Paragraph -Text "" -SpaceAfter 2
}

function Add-Caption {
    param([ValidateSet("Table", "Figure")][string]$Kind, [string]$Title)
    $selection = $script:word.Selection
    $selection.Style = $script:document.Styles.Item($wdStyleCaption)
    $selection.ParagraphFormat.Alignment = $wdAlignCenter
    if ($Kind -eq "Table") { $script:tableNumber++ } else { $script:figureNumber++ }
    $number = if ($Kind -eq "Table") { $script:tableNumber } else { $script:figureNumber }
    $selection.TypeText("$Kind $number - $Title")
    $selection.TypeParagraph()
    $selection.ParagraphFormat.Alignment = $wdAlignLeft
}

function Add-Table {
    param(
        [string]$Caption,
        [string[]]$Headers,
        [object[]]$Rows
    )
    Add-Caption -Kind "Table" -Title $Caption
    $selection = $script:word.Selection
    $start = $selection.Start
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add((($Headers | ForEach-Object { ([string]$_) -replace "[`t`r`n]+", " " }) -join "`t"))
    foreach ($row in $Rows) {
        $values = for ($column = 0; $column -lt $Headers.Count; $column++) {
            $value = if ($column -lt $row.Count) { [string]$row[$column] } else { "" }
            $value -replace "[`t`r`n]+", " "
        }
        $lines.Add(($values -join "`t"))
    }
    $selection.TypeText(($lines -join "`r"))
    $range = $script:document.Range($start, $selection.Start)
    # WdTableFieldSeparator.wdSeparateByTabs = 1.
    $table = $range.ConvertToTable([int]1, [int]($Rows.Count + 1), [int]$Headers.Count)
    $table.Borders.Enable = 1
    $table.AllowAutoFit = $false
    $table.Rows.Item(1).HeadingFormat = -1
    for ($row = 0; $row -lt $Rows.Count; $row++) {
        if (($row % 2) -eq 1) {
            $table.Rows.Item($row + 2).Shading.BackgroundPatternColor = 0xF3F6F2
        }
    }
    $table.Range.Font.Name = "Aptos"
    $table.Range.Font.Size = [single]9
    $table.Rows.Item(1).Range.Font.Size = [single]9.5
    $table.Rows.Item(1).Range.Font.Bold = 1
    $table.Rows.Item(1).Range.Font.Color = 0xFFFFFF
    $table.Rows.Item(1).Shading.BackgroundPatternColor = 0x5B3B1F
    $selection.SetRange($table.Range.End, $table.Range.End)
    $selection.TypeParagraph()
}

function Add-Callout {
    param([string]$Title, [string]$Text)
    $selection = $script:word.Selection
    $table = $script:document.Tables.Add($selection.Range, 1, 1)
    $table.Borders.Enable = 0
    $table.Cell(1, 1).Shading.BackgroundPatternColor = 0xE8F0E7
    $table.Cell(1, 1).Range.Text = "$Title`r$Text"
    $table.Cell(1, 1).Range.Font.Name = "Aptos"
    $table.Cell(1, 1).Range.Font.Size = 9.5
    $table.Cell(1, 1).Range.Paragraphs.Item(1).Range.Font.Bold = 1
    $selection.SetRange($table.Range.End, $table.Range.End)
    $selection.TypeParagraph()
}

function Add-FigurePlaceholder {
    param([string]$Title, [string]$Content)
    $selection = $script:word.Selection
    $table = $script:document.Tables.Add($selection.Range, 1, 1)
    $table.Borders.Enable = 1
    $table.Cell(1, 1).Shading.BackgroundPatternColor = 0xF4F6F4
    $table.Cell(1, 1).Range.Text = $Content
    $table.Cell(1, 1).Range.Font.Name = "Aptos Mono"
    $table.Cell(1, 1).Range.Font.Size = 8.5
    $table.Cell(1, 1).Range.ParagraphFormat.Alignment = $wdAlignCenter
    $table.Cell(1, 1).VerticalAlignment = 1
    $table.Rows.Item(1).Height = 105
    $selection.SetRange($table.Range.End, $table.Range.End)
    $selection.TypeParagraph()
    Add-Caption -Kind "Figure" -Title $Title
}

function Add-PageBreak {
    $script:word.Selection.InsertBreak($wdPageBreak)
}

function Add-ResourceSection {
    param(
        [string]$Title,
        [string]$TerraformResources,
        [string]$Purpose,
        [string]$Operation,
        [string]$Security,
        [string]$ScaleAvailability,
        [string]$FailureOperations,
        [string]$Alternatives
    )
    Add-Heading 2 $Title
    Add-Table -Caption "$Title design summary" -Headers @("Design aspect", "Implementation") -Rows @(
        @("Terraform resources", $TerraformResources),
        @("Purpose and responsibilities", $Purpose),
        @("Internal behavior and communication", $Operation),
        @("Security", $Security),
        @("Scalability and availability", $ScaleAvailability),
        @("Failure and operations", $FailureOperations),
        @("Alternatives and future improvement", $Alternatives)
    )
}

try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $word.ScreenUpdating = $false
    $word.Options.Pagination = $false
    $word.Options.CheckGrammarAsYouType = $false
    $word.Options.CheckSpellingAsYouType = $false
    $document = $word.Documents.Add()
    $word.ActiveWindow.View.Type = 1
    $script:word = $word
    $script:document = $document

    $document.PageSetup.TopMargin = $word.CentimetersToPoints(2.2)
    $document.PageSetup.BottomMargin = $word.CentimetersToPoints(2.0)
    $document.PageSetup.LeftMargin = $word.CentimetersToPoints(2.3)
    $document.PageSetup.RightMargin = $word.CentimetersToPoints(2.0)
    $document.PageSetup.DifferentFirstPageHeaderFooter = -1

    $normal = $document.Styles.Item($wdStyleNormal)
    $normal.Font.Name = "Aptos"
    $normal.Font.Size = 10.5
    $normal.Font.Color = 0x262626
    $normal.ParagraphFormat.SpaceAfter = 7
    $normal.ParagraphFormat.LineSpacingRule = 5
    $normal.ParagraphFormat.LineSpacing = 13.5

    foreach ($definition in @(
        @($wdStyleHeading1, 18, 0x5B3B1F, 14, 7),
        @($wdStyleHeading2, 14, 0x61462C, 11, 5),
        @($wdStyleHeading3, 11.5, 0x365A43, 8, 4)
    )) {
        $style = $document.Styles.Item($definition[0])
        $style.Font.Name = "Aptos Display"
        $style.Font.Size = [single]$definition[1]
        $style.Font.Color = [int]$definition[2]
        $style.Font.Bold = 1
        $style.ParagraphFormat.SpaceBefore = [single]$definition[3]
        $style.ParagraphFormat.SpaceAfter = [single]$definition[4]
        $style.ParagraphFormat.KeepWithNext = -1
    }

    # Cover page
    $selection = $word.Selection
    $selection.ParagraphFormat.Alignment = $wdAlignCenter
    1..4 | ForEach-Object { $selection.TypeParagraph() }
    $selection.Font.Name = "Aptos Display"
    $selection.Font.Size = 30
    $selection.Font.Bold = 1
    $selection.Font.Color = 0x5B3B1F
    $selection.TypeText("CHATBOT-BEDROCK")
    $selection.TypeParagraph()
    $selection.Font.Size = 18
    $selection.Font.Bold = 0
    $selection.Font.Color = 0x365A43
    $selection.TypeText("Solution Design Document")
    $selection.TypeParagraph()
    $selection.Font.Size = 12
    $selection.Font.Color = 0x666666
    $selection.TypeText("Architecture, Infrastructure, Application, CI/CD, Deployment and Operations Guide")
    $selection.TypeParagraph()
    1..4 | ForEach-Object { $selection.TypeParagraph() }
    Add-Table -Caption "Document identification" -Headers @("Attribute", "Value") -Rows @(
        @("Project", "Low-cost Amazon Bedrock RAG Chatbot (Chatbot-Bedrock)"),
        @("Author", "Elzabeth-L (repository owner; inferred from repository metadata)"),
        @("Organization", "Not specified - Chatbot-Bedrock project repository"),
        @("Document version", $version),
        @("Document date", $documentDate),
        @("Document status", "Issued for technical review"),
        @("Classification", "Confidential - project stakeholders and authorized reviewers")
    )
    Add-Paragraph -Text "CONFIDENTIALITY STATEMENT" -Bold $true -Alignment $wdAlignCenter
    Add-Paragraph -Text "This document contains project architecture, deployment, security, and operational information. Distribution should be limited to authorized project stakeholders. It contains no credentials, secret values, or private customer data." -Alignment $wdAlignCenter
    Add-PageBreak

    Add-Heading 1 "Document Control"
    Add-Table -Caption "Revision history" -Headers @("Version", "Date", "Author", "Changes") -Rows @(
        @("0.1", $documentDate, "Codex / Project Engineering", "Initial repository-derived draft"),
        @("1.0", $documentDate, "Elzabeth-L", "Issued for technical review")
    )
    Add-Table -Caption "Approvals" -Headers @("Role", "Name", "Decision", "Date") -Rows @(
        @("Solution Architect", "To be assigned", "Pending", ""),
        @("Security Reviewer", "To be assigned", "Pending", ""),
        @("DevOps / Platform Lead", "To be assigned", "Pending", ""),
        @("Project Owner", "Elzabeth-L", "Pending", "")
    )
    Add-Table -Caption "Reviewers and distribution" -Headers @("Audience", "Purpose") -Rows @(
        @("Senior architects and technical leads", "Architecture and design assurance"),
        @("DevOps and platform engineers", "Infrastructure and pipeline implementation"),
        @("Application engineers", "Frontend, Lambda, API, and data-flow maintenance"),
        @("Security reviewers", "IAM, encryption, exposure, and software assurance review"),
        @("Project and delivery managers", "Scope, deployment, cost, risk, and roadmap oversight")
    )
    Add-Callout -Title "Document basis" -Text "This document was generated from repository commit 8058cbd on branch feature/professional-chat-ui plus the subsequent documentation-plan update. Where organizational values were unavailable, the document states the omission or marks the value as inferred."
    Add-PageBreak

    Add-Heading 1 "Table of Contents"
    $tocRange = $word.Selection.Range
    $null = $document.TablesOfContents.Add($tocRange, $true, 1, 3, $true, "", $true, $true, "", $true, $true, $true)
    $word.Selection.SetRange($document.Content.End - 1, $document.Content.End - 1)
    Add-PageBreak

    Add-Heading 1 "1 Executive Summary"
    Add-Paragraph "Chatbot-Bedrock is a deliberately small, low-cost retrieval-augmented generation (RAG) application that allows browser users to ask questions against a controlled technical-document corpus. The system retrieves relevant source chunks from an Amazon Bedrock Knowledge Base backed by Amazon S3 Vectors, generates a grounded response with Amazon Nova Micro, returns sanitized citations, and retains anonymous short-lived conversation history in Amazon DynamoDB."
    Add-Paragraph "The solution addresses the common problem of providing conversational access to internal documentation without operating web servers, container clusters, vector database instances, or long-lived infrastructure credentials. It uses managed and serverless AWS services, Terraform for repeatable infrastructure, and GitHub Actions with OpenID Connect (OIDC) for short-lived deployment credentials."
    Add-Paragraph "Expected outcomes are a reproducible demonstration environment, traceable infrastructure changes, low idle cost, bounded generative-AI consumption, and a maintainable foundation for future production hardening. The current implementation is intentionally unauthenticated and therefore suitable for a controlled demonstration, not unrestricted production use."
    Add-Table -Caption "Executive solution summary" -Headers @("Dimension", "Summary") -Rows @(
        @("Business objective", "Provide fast, cited answers from an approved document corpus."),
        @("User experience", "Static responsive web application with conversation history and new-chat sessions."),
        @("Compute", "Python 3.13 AWS Lambda functions; no servers or containers."),
        @("AI and retrieval", "Bedrock Knowledge Bases, Nova Micro, Titan Text Embeddings V2, S3 Vectors."),
        @("Data", "Private S3 documents, DynamoDB TTL session messages, browser-local session index."),
        @("Delivery", "Private S3 frontend delivered through CloudFront OAC; HTTP API backend."),
        @("Automation", "Terraform 1.15.x and two GitHub Actions workflows using AWS OIDC."),
        @("Primary risk", "Public unauthenticated API can be abused and generate model charges."),
        @("Outcome", "Low-operations RAG demonstration with reviewable, exact-plan deployment.")
    )
    Add-FigurePlaceholder -Title "Overall solution architecture" -Content "USER BROWSER`n  |-- HTTPS --> CLOUDFRONT --> PRIVATE FRONTEND S3`n  |-- HTTPS --> API GATEWAY HTTP API --> CHAT LAMBDA`n                                      |-- DYNAMODB SESSION HISTORY`n                                      `-- BEDROCK KNOWLEDGE BASE --> NOVA MICRO`n                                                  |-- S3 VECTORS`n                                                  `-- PRIVATE DOCUMENT S3`nDOCUMENT S3 --> SQS BUFFER --> INGESTION LAMBDA --> BEDROCK SYNC`nCLOUDWATCH + AWS BUDGETS --> ENCRYPTED SNS ALERT TOPIC"

    Add-Heading 1 "2 System Overview"
    Add-Heading 2 "2.1 Purpose and Target Users"
    Add-Paragraph "The application is a documentation assistant for engineers and technical users. It is designed to answer questions only when retrieved knowledge-base sources support the answer. It provides source filenames and excerpts so a user can understand the grounding context. Target users are demonstration participants, developers, platform engineers, and reviewers evaluating a small AWS-native RAG pattern."
    Add-Heading 2 "2.2 Scope"
    Add-Bullets @(
        "Responsive browser frontend with a professional desktop conversation sidebar and mobile drawer.",
        "Anonymous UUID-based sessions with a browser-local index and DynamoDB-backed message history.",
        "Grounded question answering over repository-authored Markdown documents.",
        "Automatic asynchronous ingestion after document object create, update, or removal events.",
        "Terraform-managed AWS resources, monitoring, budget alerts, and secure static delivery.",
        "GitHub pull-request validation and exact reviewed Terraform plan promotion."
    )
    Add-Heading 2 "2.3 Explicit Exclusions"
    Add-Table -Caption "Technologies and capabilities not implemented" -Headers @("Item", "Status and rationale") -Rows @(
        @("Docker / container images", "Not used. Lambda code is deployed as ZIP archives and the frontend as static files."),
        @("Kubernetes / EKS", "Not used. There is no container orchestration requirement."),
        @("ECS / Fargate / ECR", "Not used. Serverless Lambda removes always-on container capacity and registry operations."),
        @("VPC, subnets, route tables, IGW, NAT Gateway", "Not created. Managed public AWS service endpoints are used; avoiding NAT removes fixed hourly cost."),
        @("ALB / NLB", "Not used. API Gateway and CloudFront are the managed ingress services."),
        @("RDS, PostgreSQL, MongoDB", "Not used. DynamoDB is sufficient for session-keyed access and S3 Vectors provides vector storage."),
        @("Authentication and authorization", "Not implemented for end users. This is the most important production gap."),
        @("AWS WAF and Bedrock Guardrails", "Not implemented to keep the demonstration small and low cost; recommended for production."),
        @("Streaming responses", "Not implemented. The browser waits for a complete RetrieveAndGenerate response."),
        @("Cross-device identity", "Not implemented. Session discovery remains in each browser's local storage.")
    )
    Add-Heading 2 "2.4 Major Features and Design Philosophy"
    Add-Paragraph "The design favors managed services, pay-for-use billing, private storage, least privilege, small bounded requests, and explicit operational evidence. Terraform remains a single application root because the resources are tightly related and there is no demonstrated module-reuse requirement. A separate bootstrap root owns only the state bucket and GitHub deployment identities, establishing a clean trust boundary."
    Add-Callout -Title "Assumption" -Text "The deployment account has Bedrock model access and compatible service quotas in us-east-1. Model and S3 Vectors availability must be revalidated before using another Region."

    Add-Heading 1 "3 Technology Stack"
    Add-Table -Caption "Implemented technology stack" -Headers @("Technology", "Version / selection", "Purpose", "Selection rationale", "Alternative considered") -Rows @(
        @("Terraform", "CLI 1.15.8; AWS provider ~> 6.55.0", "Infrastructure provisioning and state", "Declarative plans and native S3 Vectors resources", "CloudFormation/CDK; rejected to retain provider portability and reviewed plans"),
        @("GitHub Actions", "Hosted ubuntu-latest; pinned major actions", "CI, security analysis, Terraform orchestration", "Repository-native automation and OIDC", "Jenkins/Azure DevOps; unnecessary control plane"),
        @("Python", "3.13", "Chat and ingestion Lambda handlers", "AWS SDK ecosystem and compact runtime", "Node.js; no implementation need"),
        @("HTML/CSS/JavaScript", "Browser standards; no framework", "Static frontend", "Minimal dependencies and deployment footprint", "React/Angular/Vue; excessive for this scope"),
        @("AWS Lambda", "Python 3.13; 512 MB chat, 256 MB ingestion", "On-demand compute", "No idle servers and native event integrations", "ECS/Fargate or EC2"),
        @("API Gateway", "HTTP API payload v2.0", "Public HTTPS REST-style routes", "Lower cost and complexity than REST API", "ALB or REST API"),
        @("Amazon Bedrock", "RetrieveAndGenerate; Nova Micro v1", "Grounded answer generation", "Managed citations and low-cost text model", "Custom RAG orchestration or larger models"),
        @("Titan Text Embeddings V2", "amazon.titan-embed-text-v2:0; 256 dimensions", "Document/query vectorization", "Compact Amazon-native embedding", "Third-party embedding models"),
        @("S3 Vectors", "float32, cosine, 256 dimensions", "Semantic vector index", "No continuously running cluster", "OpenSearch Serverless or Aurora pgvector"),
        @("Amazon S3", "General-purpose private buckets", "Documents, static site, Terraform state", "Durable managed object storage", "EFS or public website bucket"),
        @("Amazon DynamoDB", "Standard, PAY_PER_REQUEST, TTL", "Short-lived session messages", "Serverless keyed queries and native TTL", "RDS or ElastiCache"),
        @("Amazon SQS", "Standard + encrypted DLQ", "Ingestion buffering and retry", "Decouples S3 events from Bedrock synchronization", "Direct S3-to-Lambda only"),
        @("Amazon CloudFront", "Price Class 100, default domain/certificate", "Static frontend delivery", "TLS, caching, and private OAC origin", "S3 website or Amplify Hosting"),
        @("CloudWatch / SNS / Budgets", "7-day logs; five alarms; encrypted topic", "Observability and cost alerts", "AWS-native and low operations", "Third-party monitoring platform"),
        @("SonarCloud / Snyk / CodeQL / Trivy", "CI-managed", "SAST, SCA, quality, IaC scanning", "Layered software assurance", "Single-tool coverage")
    )
    Add-Callout -Title "No container toolchain" -Text "Docker, NGINX, ECR, Kubernetes, ECS, and Fargate are absent by design. CI analyzes and Terraform deploys the exact Python and static assets used at runtime."

    Add-Heading 1 "4 High-Level Architecture"
    Add-Heading 2 "4.1 Runtime Request Flow"
    Add-NumberedSteps @(
        "The browser obtains index.html, chat.css, app.js, and generated config.js through CloudFront from a private S3 origin.",
        "The browser creates or restores a UUID and calls POST /chat on the HTTP API.",
        "API Gateway invokes the chat Lambda through an AWS_PROXY payload v2 integration.",
        "The function validates the UUID and message, retrieves at most 12 current history records, and formats bounded context.",
        "Bedrock RetrieveAndGenerate queries five vector results, invokes Nova Micro with a strict grounding prompt, and returns citations.",
        "The function rejects uncited or insufficient output, writes the user and assistant records with a common TTL, and returns JSON.",
        "The browser renders the answer and sanitized citation filename/excerpts."
    )
    Add-Heading 2 "4.2 Ingestion and Deployment Flow"
    Add-Paragraph "Terraform uploads files under knowledge-base/documents/ in the private document bucket. S3 emits create and remove events to SQS. The event source mapping batches up to 100 messages for up to 60 seconds. The ingestion Lambda checks recent Bedrock jobs, defers the batch when a job is active, or starts one idempotent incremental synchronization. Failed messages are retried and eventually redriven to the DLQ."
    Add-FigurePlaceholder -Title "Infrastructure relationship diagram" -Content "TERRAFORM ROOT`n |-- S3 DOCUMENT BUCKET --events--> SQS --> INGESTION LAMBDA`n |        `--prefix--> BEDROCK DATA SOURCE --> KB --> S3 VECTOR INDEX`n |-- DYNAMODB <--> CHAT LAMBDA <--> BEDROCK KB / NOVA`n |-- API GATEWAY --> CHAT LAMBDA`n |-- FRONTEND S3 <--OAC-- CLOUDFRONT`n `-- LOG GROUPS + ALARMS --> SNS; AWS BUDGET --> SNS`n`nBOOTSTRAP ROOT --> STATE S3 + GITHUB PLAN/DEPLOY OIDC ROLES"
    Add-FigurePlaceholder -Title "Deployment flow" -Content "FEATURE BRANCH --> PULL REQUEST --> APPLICATION CHECKS + TERRAFORM PLAN`n      --> REVIEW / APPROVAL --> MERGE TO MAIN --> FINAL-COMMIT PLAN`n      --> MANUAL 'APPLY REVIEWED CHANGES' --> VERIFY ARTIFACT PROVENANCE`n      --> APPLY EXACT BINARY PLAN --> PRINT CLOUDFRONT FRONTEND URL"
    Add-FigurePlaceholder -Title "Network architecture" -Content "INTERNET`n  |-- HTTPS 443 --> CLOUDFRONT DEFAULT DOMAIN --> SIGNED OAC --> PRIVATE S3`n  `-- HTTPS 443 --> API GATEWAY DEFAULT DOMAIN --> LAMBDA SERVICE INTEGRATION`n`nNO CUSTOMER VPC, CIDR, SUBNET, ROUTE TABLE, SECURITY GROUP, NAT, IGW, OR LOAD BALANCER"

    Add-Heading 1 "5 Infrastructure Design"
    Add-ResourceSection "5.1 Terraform State S3 Bucket" "bootstrap: aws_s3_bucket.state, versioning, encryption configuration, public access block, ownership controls, bucket policy" "Stores the application Terraform state and native S3 lock file. It is created or adopted locally before application initialization and is protected with prevent_destroy." "Terraform reads and writes one configured state key and creates a sibling .tflock object. GitHub roles receive exact bucket/key access through bootstrap policies." "AES256 server-side encryption, versioning, TLS-only bucket policy, owner-enforced ownership, and complete public-access blocking. No credentials are stored in backend configuration." "S3 provides Regional durability and concurrent lock coordination without a database. State history is recoverable through object versions." "Loss of state write permission can create resources without persisted state; stop immediately and import confirmed resources through reviewed recovery configuration. Review old versions and access logs according to organizational policy." "Terraform Cloud provides managed state and policy but adds another control plane. DynamoDB locking is deprecated; native S3 lockfiles are selected. Future: access logging, KMS CMK, replication, and break-glass recovery runbook."
    Add-ResourceSection "5.2 GitHub OIDC Plan and Deployment Roles" "bootstrap: aws_iam_role.github_plan, aws_iam_role.github_deploy and supplemental inline policies" "Issue short-lived AWS sessions to GitHub Actions without stored AWS access keys. The plan role is read-oriented; the deployment role can modify application resources and backend state." "GitHub's token.actions.githubusercontent.com identity provider supplies a signed token with aud and sub claims. Trust policies match immutable owner/repository IDs; deployment matches only refs/heads/main." "Separate trust boundaries, one-hour maximum role sessions, exact repository identity, main-only deployment, masked account ID, and least-privilege supplemental permissions." "IAM is a Regional-independent managed service. A failed OIDC assumption stops the workflow before infrastructure commands run." "Repository transfer, renamed branches, or changed IDs invalidate trust and require a reviewed bootstrap update. Audit CloudTrail AssumeRoleWithWebIdentity events." "Long-lived repository secrets were rejected. GitHub Environments were deliberately not used; branch protection plus main-only trust and exact-plan promotion provide the control. Future: permission boundaries and organization-wide identity governance."
    Add-ResourceSection "5.3 Source Document S3 Bucket" "aws_s3_bucket.documents plus access block, ownership, versioning, AES256 encryption, lifecycle, TLS policy, and aws_s3_object.documents" "Stores only repository-managed knowledge documents under knowledge-base/documents/. It is the Bedrock data source and emits change notifications." "Terraform discovers files under documents/, uploads Markdown objects, and installs S3 notifications before the initial corpus upload. Bedrock reads only the inclusion prefix." "Private bucket, blocked public access, owner-enforced ownership, TLS-only access, SSE-S3, scoped Bedrock read permissions, and 30-day expiration of noncurrent demo versions." "S3 scales automatically and provides multi-AZ durability within the Region. Versioning protects against accidental overwrites." "Incorrect prefixes do not ingest. Event delivery is at least once; SQS and idempotent ingestion handle duplicates. Monitor storage versions and force-destroy behavior before teardown." "External document systems, SharePoint connectors, or direct uploads could replace repository-managed files. Future: malware scanning, data classification, retention policy, object lock where mandated."
    Add-ResourceSection "5.4 Frontend S3 Bucket and Static Objects" "aws_s3_bucket.frontend and controls; aws_s3_object.frontend_index, frontend_styles, frontend_chat_styles, frontend_app, frontend_config" "Stores the browser application and generated non-secret API endpoint configuration. The bucket is never public." "CloudFront reads objects through OAC. index.html, app.js, and chat.css use cache controls that prevent new markup from being paired with stale assets; config.js is no-store." "Public access block, owner-enforced ownership, SSE-S3, TLS denial, and bucket policy restricted to the exact CloudFront distribution SourceArn." "S3 supports high request volume without capacity management. Static objects have no compute failure mode." "Incorrect caching may produce incompatible asset versions; the new chat.css key explicitly breaks the former cache. Validate MIME types and CloudFront responses after deployment." "S3 website hosting was rejected because it cannot use the private OAC pattern. Future: content-hashed filenames and automated CloudFront invalidation."
    Add-ResourceSection "5.5 CloudFront Distribution, OAC, and Security Headers" "aws_cloudfront_distribution.frontend, aws_cloudfront_origin_access_control.frontend, aws_cloudfront_response_headers_policy.security" "Provides the public HTTPS frontend endpoint, edge caching, compression, protocol redirection, and signed access to private S3." "Viewer GET/HEAD/OPTIONS requests are redirected to HTTPS and served from the S3 origin. OAC signs origin requests with SigV4. Security headers apply at the edge." "CSP restricts scripts/styles to self and connections to HTTPS; frame denial, HSTS, referrer policy, content-type protection, and legacy XSS protection are enabled." "CloudFront is globally distributed; Price Class 100 limits edge locations to reduce cost. The S3 origin remains durable." "A bad CSP can block the API; stale cache can delay releases. Validate headers and frontend behavior. The default certificate/domain limits TLS policy selection." "A custom domain with ACM and modern TLS policy is the production path. WAF and access logs are recommended for public deployment."
    Add-ResourceSection "5.6 S3 Vector Bucket and Index" "aws_s3vectors_vector_bucket.knowledge_base, aws_s3vectors_index.knowledge_base, vector bucket policy" "Stores semantic vectors used by the Bedrock Knowledge Base without an always-running vector cluster." "Titan generates 256-dimension FLOAT32 embeddings. The index uses cosine distance. Bedrock's role can put, get, delete, and query only the selected index." "AES256 encryption and a bucket policy constrained to the account principal plus exact knowledge-base role ARN. No public data path exists." "S3 Vectors scales as a managed service. Query cost grows with index size; the selected dimensions minimize storage and processed bytes." "Region/provider incompatibility blocks creation. Deleted vectors may remain billable for up to a day. Monitor ingestion state, index size, and query quality." "OpenSearch Serverless and Aurora pgvector offer richer/hybrid search but add baseline operations/cost. Future: formal RAG quality evaluation and dimension/model comparison."
    Add-ResourceSection "5.7 Bedrock Knowledge Base and Data Source" "aws_bedrockagent_knowledge_base.this, aws_bedrockagent_data_source.documents" "Coordinates retrieval over the approved S3 corpus and connects embeddings, vectors, and generation." "The VECTOR knowledge base uses Titan V2 embeddings and the S3 Vectors index. The S3 data source includes one prefix, deletes removed content, and chunks at 500 tokens with 15 percent overlap." "A dedicated role reads only the source prefix, invokes only the embedding model, and operates only the vector index. Chat retrieval is scoped where AWS supports resource-level authorization." "Bedrock is managed; availability follows Regional service quotas. Ingestion is asynchronous and eventually consistent." "Apply success does not prove ingestion completion. Model access, quota, role propagation, or malformed documents can fail jobs. Inspect ingestion job status and logs." "A custom retrieve-then-generate flow offers more control but more code. Future: reranking, Guardrails, evaluation datasets, hybrid retrieval, and ingestion status polling."
    Add-ResourceSection "5.8 SSM Parameters" "aws_ssm_parameter.generation_model_id, aws_ssm_parameter.knowledge_base_id and corresponding data sources" "Expose Terraform-managed model and knowledge-base identifiers to deployment-time configuration." "Terraform creates String parameters, reads them as data sources, and injects resolved values into the chat Lambda environment. Runtime requests do not call SSM." "Values are identifiers, not secrets. IAM access is deployment-time; the application receives only required identifiers." "Parameter Store is managed and durable. This use avoids configuration duplication." "A missing or stale parameter prevents planning or deploys the wrong model identifier. Changes must be reviewed with model/Region compatibility." "Direct Terraform references are simpler, but parameters provide explicit configuration records. Secrets Manager is unnecessary because these values are non-sensitive."
    Add-ResourceSection "5.9 DynamoDB Session Table" "aws_dynamodb_table.sessions" "Stores short-lived user and assistant messages by anonymous session UUID and chronological message ID." "Partition key is session_id; sort key is message_id. PAY_PER_REQUEST capacity scales automatically. expires_at drives TTL; reads also filter logically expired records before asynchronous deletion." "Server-side encryption is enabled. The chat role receives Query, PutItem, and BatchWriteItem only. No table scan is performed." "On-demand capacity adapts to variable workloads. A single hot session could create a hot partition, but the demonstration's bounded use is small." "The two writes for a turn are batch operations, not a transaction; partial semantic turns are a limitation. TTL deletion is best effort. Monitor throttled requests." "RDS adds capacity and schema operations. ElastiCache is not durable. Future: transactional turn objects, PITR, authenticated user partitioning, and backup policies."
    Add-ResourceSection "5.10 Chat Lambda and Log Group" "aws_lambda_function.chat, aws_cloudwatch_log_group.chat" "Validates HTTP requests, restores bounded history, invokes Bedrock RetrieveAndGenerate, sanitizes citations, persists messages, and returns structured JSON." "Python 3.13 ZIP, 512 MB, 45-second timeout. Adaptive SDK retries are capped. Retrieval returns five results; generation is bounded to 600 tokens at temperature 0.1/topP 0.9." "Input is limited to 2,000 characters; UUIDs are canonical; raw private S3 URIs are not exposed; IAM is scoped except the documented RetrieveAndGenerate wildcard required by AWS." "Lambda scales per request using account concurrency. No reserved concurrency is configured, preserving compatibility with low-quota accounts." "Bedrock throttling returns 429; AWS failures return 502; unhandled failures return 500. Logs use structured event records and seven-day retention by default." "Containers or ECS were rejected. Future: authentication claims, idempotent writes, provisioned concurrency only if latency evidence justifies it, and tracing."
    Add-ResourceSection "5.11 Ingestion Lambda and Log Group" "aws_lambda_function.ingestion, aws_cloudwatch_log_group.ingestion" "Coalesces document events and starts one Bedrock incremental ingestion job." "Python 3.13 ZIP, 256 MB, 60-second timeout. It lists recent jobs, returns batch failures while another job is active, and generates a deterministic idempotency token from SQS message IDs." "Dedicated IAM allows its log group, one SQS queue, and list/start ingestion for the selected knowledge base/data source." "Lambda uses unreserved account concurrency; SQS batching prevents a job storm. Bedrock synchronization remains eventually consistent." "Exceptions increment Lambda Errors and trigger SQS retry. Repeated failure reaches the DLQ. Operators inspect ingestion_started, ingestion_deferred, and ingestion_start_failed events." "Step Functions could poll jobs but adds complexity. Future: explicit status polling, alarms for stale ingestion, and controlled replay tooling."
    Add-ResourceSection "5.12 SQS Ingestion Queue, DLQ, and Event Mapping" "aws_sqs_queue.ingestion, aws_sqs_queue.ingestion_dlq, queue policy, S3 notification, Lambda event source mapping" "Buffers S3 object events, absorbs bursts, supports retry/backoff, and isolates poison events." "The standard queue uses 480-second visibility, four-day retention, long polling, and maxReceiveCount 8. The DLQ retains messages for 14 days. Batch size is 100 with a 60-second window and partial-batch response." "SQS-managed encryption. Queue policy permits SendMessage only from the exact document bucket and source account. Lambda consumption is scoped to one queue." "SQS and Lambda scale automatically and provide at-least-once delivery. Duplicate events are expected and safe." "Visibility that is shorter than processing can duplicate work; active Bedrock jobs intentionally cause retries. The DLQ alarm must be investigated and messages replayed only after correcting cause." "Direct S3-to-Lambda lacks durable buffering. EventBridge adds routing capability not required here. Future: formal DLQ replay procedure."
    Add-ResourceSection "5.13 API Gateway HTTP API" "aws_apigatewayv2_api.chat, integration, two routes, default stage, API log group, Lambda permission" "Exposes POST /chat and GET /sessions/{sessionId}/messages over HTTPS and invokes the chat Lambda." "A payload-format 2.0 AWS_PROXY integration has a 29-second API timeout. The auto-deployed default stage enables detailed metrics, JSON access logs, CORS for the CloudFront origin, 5 requests/second sustained and 10 burst by default." "Managed TLS, narrow CORS origin/method/header configuration, Lambda SourceArn permission, and access logs without request bodies. End-user authentication is absent." "HTTP API is managed and scales automatically. Stage throttling controls load but is not a strong per-client abuse control." "Requests longer than the integration timeout fail even if Lambda continues. Misconfigured CORS blocks browsers. Monitor 5xx, Lambda duration/errors, and access logs." "REST API supports usage plans and richer features at higher cost. Future: JWT authorizer, WAF, custom domain, per-client quota, and access-log correlation."
    Add-ResourceSection "5.14 Runtime IAM Roles and Policies" "knowledge-base, chat, and ingestion aws_iam_role/aws_iam_role_policy resources plus trust documents" "Separate duties among Bedrock retrieval/indexing, interactive chat, and document ingestion." "Lambda trusts only lambda.amazonaws.com. The knowledge-base role trusts bedrock.amazonaws.com with SourceAccount and SourceArn conditions. Inline policies reference exact tables, queues, logs, model ARNs, prefixes, and vector index." "Least privilege is implemented. bedrock:RetrieveAndGenerate uses Resource '*' only because AWS does not support resource scoping; bedrock:Retrieve is separately scoped to the exact KB." "IAM is managed and highly available. Role-policy propagation can create transient first-apply races; explicit dependencies reduce them." "AccessDenied errors require comparing CloudTrail/API error actions with the IAM matrix, then narrowing any necessary correction. Never broaden unrelated statements." "One shared role was rejected. Future: permissions boundaries, Access Analyzer, organization SCP alignment, and periodic unused-permission review."
    Add-ResourceSection "5.15 SNS Alert Topic and Subscription" "aws_sns_topic.alerts, topic policy, optional email subscription" "Centralizes notifications from CloudWatch alarms and AWS Budgets." "CloudWatch and Budgets service principals publish to one topic. An optional email endpoint receives messages after subscription confirmation." "Encrypted with the AWS-managed SNS key. Policy grants owner management and publish only to the expected AWS services." "SNS is managed and supports fan-out. Email is best-effort and not an incident-management guarantee." "Unconfirmed subscriptions receive nothing. Operators must confirm email and test alarm notification paths." "ChatOps/PagerDuty integrations improve operational response. A customer-managed KMS key is a production option where policy mandates it."
    Add-ResourceSection "5.16 CloudWatch Logs and Alarms" "three log groups and five aws_cloudwatch_metric_alarm resources" "Provides short-retention diagnostic logs and alerts for chat error percentage, ingestion errors, visible DLQ messages, API 5xx responses, and DynamoDB throttling." "Alarms evaluate five-minute periods and treat missing data as not breaching. The chat alarm calculates errors as a percentage of invocations. All alarm actions publish to SNS." "Logs omit secrets and API request bodies. Retention defaults to seven days to limit data and cost. IAM restricts log writes by function." "CloudWatch is managed. Alarms detect service health but no dashboard or distributed trace is implemented." "Metric alarms can miss semantic failures, poor answers, and ingestion latency. Operators correlate API request IDs and structured Lambda events." "Future: dashboard, X-Ray tracing, synthetic canaries, RAG quality metrics, latency percentiles, and centralized log archive."
    Add-ResourceSection "5.17 AWS Monthly Budget" "aws_budgets_budget.monthly" "Provides advisory monthly cost notifications at 80 percent actual and 100 percent forecast of the configured USD amount." "AWS Budgets publishes notifications to SNS. The demo defaults to USD 10 per month." "Budget policy publication is restricted to the alerts topic. Budget values and alert destinations are configuration, not secrets." "Budget evaluation is managed but not real time. It does not throttle, stop, or destroy resources." "Public API abuse may generate spend before a delayed alert. Billing dashboards and anomaly detection should complement the budget." "Automated budget actions or organizational cost controls can provide stronger enforcement. Maintain conservative throttles and destroy unused demos."

    Add-Heading 1 "6 Networking"
    Add-Heading 2 "6.1 Network Model"
    Add-Paragraph "The application defines no customer-managed network. Consequently there are no CIDR ranges, subnets, route tables, security groups, internet gateway, NAT gateway, VPC endpoints, or load balancer. Public ingress terminates at AWS-managed CloudFront and API Gateway endpoints. Service-to-service calls use AWS managed networking and IAM authorization."
    Add-Table -Caption "Network communication matrix" -Headers @("Source", "Destination", "Protocol / interface", "Control") -Rows @(
        @("Browser", "CloudFront", "HTTPS 443", "CloudFront certificate, HTTPS redirect, security headers"),
        @("CloudFront", "Frontend S3", "Signed HTTPS S3 origin request", "OAC and SourceArn-restricted bucket policy"),
        @("Browser", "API Gateway", "HTTPS 443, GET/POST/OPTIONS", "CORS origin, route throttling; no auth"),
        @("API Gateway", "Chat Lambda", "AWS service invoke", "Lambda resource policy scoped to API execution ARN"),
        @("Chat Lambda", "DynamoDB / Bedrock", "AWS SDK HTTPS", "Execution-role IAM"),
        @("S3", "SQS", "AWS service event", "Queue policy SourceArn and SourceAccount"),
        @("SQS", "Ingestion Lambda", "Lambda event source polling", "Execution-role IAM and event mapping"),
        @("Bedrock", "S3 / S3 Vectors", "Managed service APIs", "Knowledge-base role and bucket/index policies")
    )
    Add-Heading 2 "6.2 DNS, TLS, and High Availability"
    Add-Paragraph "CloudFront and API Gateway supply AWS default DNS names and managed certificates. CloudFront redirects HTTP to HTTPS. The frontend distribution uses the CloudFront default certificate; selecting a modern custom minimum TLS policy requires a custom domain and ACM certificate. The serverless services span AWS-managed availability infrastructure, but the application is deployed in one Region and has no cross-Region failover."
    Add-Callout -Title "Production recommendation" -Text "Introduce a custom domain, ACM certificate, WAF, JWT authorizer, CloudFront/API access logs, and regional recovery objectives before exposing business or sensitive content. Add a VPC only when private resources or organizational egress controls create a real requirement."

    Add-Heading 1 "7 Application Architecture"
    Add-Heading 2 "7.1 Frontend"
    Add-Paragraph "The frontend is framework-free HTML, CSS, and JavaScript. It presents a fixed desktop history rail, compact active conversation rows, a centered chat reading column, citations, a responsive composer, and an accessible off-canvas history drawer on small screens. The first user prompt becomes the local chat title. Textarea growth, Escape-to-close, backdrop handling, focus behavior, and ARIA attributes support usability."
    Add-Paragraph "The browser stores only a current session UUID plus an index of up to 25 session IDs, display titles, and update timestamps. Message content is restored from DynamoDB through the history API. Local storage is a convenience index, not an identity boundary; it does not synchronize between devices and can be cleared by the user."
    Add-Heading 2 "7.2 Backend Modules"
    Add-Table -Caption "Application module responsibilities" -Headers @("Module", "Responsibilities") -Rows @(
        @("frontend/index.html", "Semantic application shell, navigation, empty state, chat form, and static asset references."),
        @("frontend/styles.css", "Desktop/mobile layout, responsive drawer, messages, citations, accessibility focus, and reduced-motion behavior."),
        @("frontend/app.js", "Session registry, UUID lifecycle, title generation, history retrieval, chat requests, rendering, and UI state."),
        @("lambdas/chat/handler.py", "Validation, routing, bounded history, RetrieveAndGenerate call, grounding enforcement, citations, persistence, and errors."),
        @("lambdas/ingestion/handler.py", "Event coalescing, active-job detection, idempotent ingestion start, retry signaling, and structured logging."),
        @("documents/*.md", "Small repository-authored demonstration knowledge corpus.")
    )
    Add-Heading 2 "7.3 API Contract"
    Add-Table -Caption "HTTP API routes" -Headers @("Route", "Request", "Success response", "Validation and errors") -Rows @(
        @("POST /chat", "JSON: sessionId UUID, message string up to 2,000 characters", "200: sessionId, answer, citations[]", "400 invalid input; 429 AWS throttle; 502 dependency failure; 500 unexpected failure"),
        @("GET /sessions/{sessionId}/messages", "Canonical UUID path parameter", "200: sessionId and up to 100 unexpired chronological messages", "400 invalid UUID; unknown/expired session returns empty list")
    )
    Add-Heading 2 "7.4 Data, Caching, and Background Processing"
    Add-Paragraph "DynamoDB is the system of record for message content during the configured TTL window. The browser caches only navigation metadata. CloudFront caches static assets; index, JavaScript, configuration, and the redesigned stylesheet use release-safe cache policies. The asynchronous ingestion path is S3 to SQS to Lambda to Bedrock. There is no application-level response cache, WebSocket, worker server, or scheduled job."
    Add-Heading 2 "7.5 Authentication and Authorization"
    Add-Paragraph "The public HTTP API has no user authentication or authorization. A UUID prevents accidental key collisions but is not a credential. Runtime AWS authorization is enforced through IAM service roles. This distinction is material: end-user data isolation and access control are not provided."

    Add-Heading 1 "8 Infrastructure as Code"
    Add-Heading 2 "8.1 Terraform Architecture"
    Add-Paragraph "The repository uses two root modules. bootstrap/ is local-only and owns the remote-state S3 bucket plus persistent GitHub OIDC roles. terraform/ owns the application services. The application root intentionally does not create its own backend, avoiding the Terraform bootstrap paradox."
    Add-FigurePlaceholder -Title "Terraform root and state relationship" -Content "LOCAL OPERATOR`n   `-- terraform -chdir=bootstrap apply`n          |-- S3 STATE BUCKET (prevent_destroy)`n          |-- GITHUB PLAN OIDC ROLE`n          `-- GITHUB DEPLOY OIDC ROLE`n`nAPPLICATION TERRAFORM / GITHUB ACTIONS`n   `-- backend.hcl --> EXISTING STATE BUCKET / exact key + .tflock`n   `-- terraform/ --> ALL APPLICATION RESOURCES"
    Add-Heading 2 "8.2 State, Locking, and Execution"
    Add-Paragraph "backend.tf declares a partial S3 backend. Environment-specific bucket, key, Region, encryption, and use_lockfile=true values are supplied through an ignored backend.hcl locally or generated from GitHub Variables in CI. Native S3 lock files coordinate writers; legacy DynamoDB state locking is not used. State and lock objects have distinct least-privilege permissions."
    Add-NumberedSteps @(
        "Create or import the backend bucket and OIDC roles with the bootstrap root.",
        "Create ignored backend.hcl and terraform.tfvars for local work, or configure repository Variables for CI.",
        "Run terraform fmt, init, validate, and a saved plan with the committed variable file.",
        "Review resource actions, IAM changes, replacements, and cost-bearing resources.",
        "Apply only the exact reviewed binary plan in the same environment and toolchain."
    )
    Add-Heading 2 "8.3 Dependency Graph and Best Practices"
    Add-Bullets @(
        "References express resource ordering; explicit depends_on is used where AWS side effects are not represented by normal attributes.",
        "S3 notification installation precedes initial document upload so first deployment schedules ingestion.",
        "The vector bucket policy waits for the knowledge-base role policy to reduce IAM propagation races.",
        "Variables include validation and safe non-secret defaults; generated names share project/environment tags.",
        "Outputs expose operational identifiers and URLs but no credentials.",
        "Binary plan, provider lock, Lambda ZIPs, checksums, backend identity, variable identity, and provenance are promoted together."
    )
    Add-Heading 2 "8.4 Recovery and Drift"
    Add-Paragraph "If apply creates resources but cannot persist state, operators must stop. After repairing backend permissions, confirm each created resource and adopt it using reviewed Terraform import blocks; do not rerun against an empty state. Read-oriented plans refresh remote state and expose drift. The recovery_imports.tf file records previous declarative recovery history and should be reviewed before reuse."

    Add-Heading 1 "9 CI/CD Pipeline Documentation"
    Add-Heading 2 "9.1 Repository and Workflow Model"
    Add-Paragraph "There are exactly two top-level workflows: application.yml and terraform.yml. Terraform shell implementation is encapsulated in repository-local composite actions, leaving the top-level Terraform workflow declarative with no run or script blocks. No GitHub Environments are used; repository Variables/Secrets, branch protection, OIDC claims, and explicit operation choices provide control."
    Add-Heading 2 "9.2 Application CI Workflow"
    Add-Table -Caption "Application CI jobs" -Headers @("Job", "Trigger / dependency", "Purpose", "Failure behavior") -Rows @(
        @("Detect application changes", "Every PR; relevant main pushes; manual", "paths-filter determines whether application assets changed", "Stops conditional downstream execution only when detection fails"),
        @("Tests and lint", "Application change or manual", "Python 3.13, Ruff, pytest coverage artifact", "Lint/test failure blocks PR"),
        @("CodeQL SAST", "Application change or manual; Python and JavaScript matrix", "security-extended static analysis and SARIF", "Finding/configuration outcome follows code scanning rules"),
        @("Snyk SCA and SAST", "Internal PR/application change or manual", "High-severity dependency and code scanning; SARIF upload", "Skipped with notice if token/org absent; findings fail configured commands"),
        @("SonarCloud analysis", "After tests, internal PR/application change or manual", "Consumes coverage and waits up to 300 seconds for quality gate", "Skipped with notice if configuration absent; gate failure blocks")
    )
    Add-Paragraph "All required check names are reported on pull requests, but expensive application analysis does not run for infrastructure-only changes. On main, only relevant application paths trigger this workflow. This optimization reduces external scan usage and feedback noise without leaving branch protection waiting."
    Add-Heading 2 "9.3 Terraform Plan Workflow"
    Add-NumberedSteps @(
        "Checkout the exact commit and assume the read-oriented AWS plan role through OIDC.",
        "Install the exact Terraform version from the repository variable.",
        "Validate non-sensitive configuration and create an ephemeral backend.hcl with restrictive permissions.",
        "Run formatting, init, validate, and a blocking Trivy HIGH/CRITICAL configuration scan.",
        "Create either a change plan or destroy plan as a binary file and a human-readable rendering.",
        "Package the plan, provider lockfile, both Lambda ZIP archives, readable plan, and immutable metadata with SHA-256 checksums.",
        "Upload a seven-day artifact and publish a bounded plan summary; internal PRs receive a sticky comment."
    )
    Add-Heading 2 "9.4 Exact Plan Promotion"
    Add-Paragraph "Apply and destroy apply are manual workflow-dispatch operations available only when the workflow is run from main. The promotion composite action automatically finds the newest successful, unexpired plan for the exact commit and requested mode from a manual or main-push run. PR artifacts are not normally promotable because the merge commit differs."
    Add-Table -Caption "Immutable promotion validations" -Headers @("Validation", "Protected condition") -Rows @(
        @("Source", "Same repository, approved workflow path, successful manual/main-push event, non-fork head"),
        @("Revision", "Exact expected commit SHA and plan mode"),
        @("Toolchain", "Exact Terraform version, runner OS/architecture, provider lock checksum"),
        @("Configuration", "Working directory, backend identity, tfvars checksum"),
        @("Payload", "Binary plan checksum and both Lambda ZIP checksums"),
        @("Freshness", "Creation time is not future-dated and age is at most seven days"),
        @("Confirmation", "Exact apply or destroy confirmation matches job mode")
    )
    Add-Paragraph "After validation, Terraform applies the included binary plan without replanning. A successful change apply writes the complete CloudFront frontend URL to the job log and summary. There is no automatic rollback because Terraform cannot generically reverse arbitrary stateful changes; rollback is a new reviewed forward plan or, where safe, the protected destroy workflow."
    Add-FigurePlaceholder -Title "CI/CD workflow sequence" -Content "PR OPEN/UPDATE`n |-- Application CI (path-aware): Ruff + pytest + CodeQL + Snyk + SonarCloud`n `-- Terraform CI: OIDC plan --> scan --> binary artifact --> PR comment`n`nREVIEW + MERGE`n `-- main push --> relevant Application CI + exact merge-commit Terraform plan`n`nMANUAL DISPATCH FROM MAIN`n `-- Apply reviewed changes --> resolve artifact --> verify all metadata/checksums --> terraform apply"
    Add-Heading 2 "9.5 Pipeline Security, Caching, and Failure Handling"
    Add-Bullets @(
        "AWS credentials are short lived through OIDC; no AWS access keys are stored in GitHub.",
        "SONAR_TOKEN and SNYK_TOKEN are GitHub Secrets; organization/project identifiers are GitHub Variables.",
        "No secret value is printed, written to artifacts, or embedded in static assets.",
        "Python setup caches pip dependencies; concurrency cancels superseded application runs but never cancels Terraform operations.",
        "Fork pull requests receive no AWS, Sonar, or Snyk credentials and produce no promotable Terraform artifact.",
        "Trivy exceptions are narrow, documented, time bounded, and limited to accepted demo design choices.",
        "Plan artifacts expire after seven days and all verification fails closed."
    )

    Add-Heading 1 "10 Pull Request Workflow"
    Add-Paragraph "The repository follows a lightweight feature-branch workflow aligned with trunk-based development: main remains the integration and deployment branch; short-lived feature branches carry individual changes. Direct feature development on main is discouraged."
    Add-NumberedSteps @(
        "Create or update a feature branch from current main.",
        "Update docs/implementation-plan.md before implementation when scope changes.",
        "Implement and validate only the intended files; never commit credentials or local backend/variable files.",
        "Commit with a focused message and push the feature branch.",
        "Open a pull request targeting main and review the application checks plus Terraform plan artifact/comment.",
        "Address failures and review comments on the same feature branch.",
        "Obtain required approval or use the explicitly configured repository-owner bypass only where governance permits.",
        "Merge to main; the merge commit triggers relevant application validation and a new promotable Terraform plan.",
        "Review the final-commit plan, then manually select Apply reviewed changes from main."
    )
    Add-FigurePlaceholder -Title "Pull request lifecycle" -Content "DEVELOPER --> FEATURE BRANCH --> COMMIT --> PUSH --> PULL REQUEST`n    --> CODE REVIEW + APPLICATION CHECKS + TERRAFORM PLAN`n    --> APPROVAL / OWNER BYPASS (repository policy)`n    --> MERGE TO MAIN --> FINAL PLAN --> MANUAL REVIEWED APPLY"

    Add-Heading 1 "11 Security"
    Add-Heading 2 "11.1 Security Control Summary"
    Add-Table -Caption "Implemented security controls" -Headers @("Domain", "Control") -Rows @(
        @("Identity", "Separate runtime roles and separate GitHub plan/deploy OIDC roles; no stored AWS access keys."),
        @("Least privilege", "Resource-scoped policies for logs, table, queues, S3 prefixes, models, and vector index; documented AWS wildcard exceptions."),
        @("Storage", "Private S3, public-access blocks, TLS-deny policies, owner enforcement, versioning where required, and encryption at rest."),
        @("Transport", "HTTPS at CloudFront and API Gateway; CloudFront redirects HTTP."),
        @("Application", "Canonical UUID validation, input limits, bounded history/results/output, sanitized citations, structured errors."),
        @("Edge", "CSP, HSTS, frame denial, MIME sniffing protection, referrer policy, OAC."),
        @("Software assurance", "Ruff, pytest, CodeQL, Snyk SCA/SAST, SonarCloud, Trivy IaC scanning."),
        @("Secrets", "Only Snyk/Sonar tokens in GitHub Secrets; no application secret or credential in source/workflows/logs."),
        @("Cost abuse", "API throttles, bounded model usage, alarms, and mandatory AWS Budget.")
    )
    Add-Heading 2 "11.2 Residual Risks"
    Add-Bullets @(
        "The API is unauthenticated; a discovered endpoint can be invoked outside the frontend.",
        "A UUID is not proof of identity, so possession permits session-history retrieval until expiry.",
        "No WAF, bot control, per-client quota, or Bedrock Guardrail is deployed.",
        "CloudTrail data-event and application audit requirements are not configured by this root.",
        "AWS-managed encryption keys reduce cost but provide less key-policy separation than customer-managed keys.",
        "Client-side rendering must continue to use textContent; introducing unsafe HTML would create XSS risk."
    )
    Add-Heading 2 "11.3 Production Security Roadmap"
    Add-Paragraph "Before production, introduce enterprise identity through an API Gateway JWT authorizer or Cognito/external IdP; bind partitions to authenticated subject claims; add WAF managed rules and rate-based controls; configure Guardrails and abuse monitoring; use custom domains and policy-controlled TLS; evaluate customer-managed KMS keys; enable organization-standard CloudTrail and access logging; conduct threat modeling, penetration testing, privacy review, and data-retention approval."

    Add-Heading 1 "12 Monitoring and Logging"
    Add-Heading 2 "12.1 Current Monitoring Strategy"
    Add-Paragraph "Operational monitoring focuses on availability, error rate, asynchronous ingestion failure, and cost. Lambda and API logs retain seven days by default. API logs include request ID, route, status, response length, and integration error - not body content. Lambda logs use JSON event labels that support search and correlation."
    Add-Table -Caption "Alarm catalogue" -Headers @("Alarm", "Metric / threshold", "Operator action") -Rows @(
        @("Chat error rate", "Lambda Errors / Invocations; default >=5 percent, 1 of 2 five-minute periods", "Inspect request IDs, Lambda logs, Bedrock/DynamoDB dependency errors and quotas."),
        @("Ingestion failures", "Ingestion Lambda Errors >=1 in five minutes", "Inspect ingestion_start_failed, IAM, quota, and Bedrock jobs."),
        @("Ingestion DLQ", "Visible DLQ messages >=1", "Correct root cause, verify idempotency, and perform controlled replay."),
        @("API 5xx", "HTTP API 5xx >=3 in five minutes", "Correlate API access log and chat Lambda errors/duration."),
        @("DynamoDB throttles", "ThrottledRequests >=1", "Check hot session partitions, account limits, and traffic abuse.")
    )
    Add-Heading 2 "12.2 Health Checks and Operational Gaps"
    Add-Paragraph "There is no dedicated /health route, dashboard, synthetic canary, distributed trace, container health check, or pod health because the system has no containers or cluster. A successful HTTP response proves request-path health; a grounded answer plus citation proves the full RAG path. The smoke-test script validates frontend and API endpoints after deployment."
    Add-Heading 2 "12.3 Recommended Runbook Sequence"
    Add-NumberedSteps @(
        "Confirm the CloudFront URL serves the current branded shell and chat.css without browser console errors.",
        "Inspect API Gateway status/access logs for the request ID and route result.",
        "Inspect chat Lambda logs and metrics for throttling, access denied, timeout, or dependency errors.",
        "Confirm Bedrock Knowledge Base/data-source ingestion job status is COMPLETE.",
        "Check the SQS source queue and DLQ, then the ingestion Lambda logs.",
        "Check DynamoDB TTL/throttle metrics and verify records are unexpired.",
        "Review AWS Budget/Billing for unexpected request or model growth."
    )

    Add-Heading 1 "13 Deployment Guide"
    Add-Heading 2 "13.1 Prerequisites"
    Add-Bullets @(
        "AWS account with Bedrock Knowledge Bases, S3 Vectors, Nova Micro, and Titan Text Embeddings V2 available in us-east-1.",
        "Model access/activation and adequate Bedrock, Lambda, IAM, S3, and S3 Vectors quotas.",
        "Terraform 1.15.8 for local parity; Python 3.13 and pip for local tests; AWS CLI only for authorized diagnostics.",
        "Existing GitHub OIDC provider plus bootstrap permissions to create/adopt state bucket and two repository roles.",
        "GitHub branch protection, repository Variables, and SNYK_TOKEN/SONAR_TOKEN Secrets.",
        "A unique state bucket name and reviewed non-secret tfvars file."
    )
    Add-Heading 2 "13.2 Bootstrap and Repository Configuration"
    Add-NumberedSteps @(
        "Review bootstrap/bootstrap.tfvars and confirm the unique state bucket, Region, state key, immutable repository identity, and approved feature branch.",
        "Run terraform -chdir=bootstrap init, plan, and apply locally. If the bucket already exists, import it instead of recreating it.",
        "Record bootstrap outputs and configure AWS_PLAN_ROLE_ARN, AWS_DEPLOY_ROLE_ARN, AWS_REGION, TERRAFORM_VERSION, TF_BACKEND_BUCKET, TF_STATE_KEY, and TFVARS_FILE as GitHub Repository Variables.",
        "Configure SNYK_ORG, SONAR_ORGANIZATION, and SONAR_PROJECT_KEY as Variables; store SNYK_TOKEN and SONAR_TOKEN only as Secrets.",
        "Protect main with pull-request and required-check rules consistent with the repository-owner bypass decision."
    )
    Add-Heading 2 "13.3 Application Deployment"
    Add-NumberedSteps @(
        "Push the implementation to a feature branch and open a PR.",
        "Wait for application checks and Terraform plan; inspect the complete plan artifact and concise PR comment.",
        "Approve and merge only after risks, replacements, IAM, and cost changes are understood.",
        "Review the automatic Terraform plan generated for the exact merge commit on main.",
        "From Actions > Terraform, select Use workflow from: main and Operation: Apply reviewed changes.",
        "Verify the job selected the intended plan and completed exact artifact validation.",
        "Open the Frontend URL printed in the promotion summary; do not use the API Gateway URL as the web page.",
        "Confirm ingestion reaches COMPLETE, ask corpus-supported questions, restore history, and create a new chat."
    )
    Add-Heading 2 "13.4 Validation and Testing"
    Add-Table -Caption "Deployment validation checklist" -Headers @("Check", "Expected result") -Rows @(
        @("Terraform outputs", "Frontend/API URLs, KB/data-source IDs, bucket/table/topic/budget identifiers are present."),
        @("CloudFront", "HTTPS, current UI stylesheet, security headers, private S3 origin."),
        @("API", "POST chat returns cited answer for corpus-supported question; invalid input returns structured 400."),
        @("History", "Refresh and session selection restore unexpired DynamoDB messages; New chat creates a new UUID."),
        @("Ingestion", "S3 document change produces queued event and COMPLETE Bedrock ingestion job."),
        @("Monitoring", "Log groups have correct retention and alarms publish to confirmed SNS subscription."),
        @("Security", "S3 public access is blocked; no secret values appear in browser assets or workflow logs."),
        @("Cost", "Budget exists at intended monthly limit and Billing shows expected low usage.")
    )
    Add-Heading 2 "13.5 Rollback and Destroy"
    Add-Paragraph "Rollback is performed as a new reviewed forward change. Revert the source through a PR, let main generate an exact plan, and manually promote that plan. For complete teardown, select Plan destruction from main, review the destroy artifact, then select Apply reviewed destruction for the same commit. The state bucket and bootstrap OIDC roles remain intentionally protected and require a separate explicit lifecycle decision."
    Add-Callout -Title "Destructive operation" -Text "force_destroy_buckets=true permits Terraform to remove demo object versions and vectors during a reviewed destroy. Confirm retention obligations and the exact plan before promotion. AWS Budgets does not stop spending automatically."

    Add-Heading 1 "14 Cost Analysis"
    Add-Heading 2 "14.1 Estimation Basis"
    Add-Paragraph "Pricing was reviewed on 03 August 2026 against AWS primary pricing/documentation sources. Estimates are directional, exclude tax and support plans, assume us-east-1, and must be recalculated in AWS Pricing Calculator before production approval. AWS Free Tier eligibility depends on account age and program terms and is never treated as guaranteed."
    Add-Table -Caption "Illustrative monthly workload assumptions" -Headers @("Parameter", "Development", "Illustrative production") -Rows @(
        @("Questions", "1,000", "100,000"),
        @("Average model input / output", "1,500 / 400 tokens", "1,500 / 400 tokens"),
        @("Retrieval calls", "1,000", "100,000"),
        @("API calls", "2,000", "200,000"),
        @("Average chat Lambda duration", "3 seconds at 512 MB", "3 seconds at 512 MB"),
        @("CloudFront transfer", "1 GB", "50 GB"),
        @("Knowledge corpus", "<0.1 GB and small vector index", "1 GB and moderate vector index")
    )
    Add-Table -Caption "Service-level monthly cost estimate" -Headers @("Service", "Pricing model / reference rate", "Development", "Illustrative production", "Optimization") -Rows @(
        @("Amazon Nova Micro", "On-demand: USD 0.000035/1K input; USD 0.00014/1K output tokens", "~USD 0.11", "~USD 10.85", "Bound context/output; evaluate quality before choosing larger model"),
        @("Bedrock KB retrieval", "Current standard retrieval example: USD 1/1K queries; verify applicability", "~USD 1.00", "~USD 100.00", "Cache stable answers only with correctness controls; reduce unnecessary calls"),
        @("Titan Embeddings V2", "~USD 0.02 per million input tokens at ingestion", "<USD 0.01", "Corpus/change dependent", "Incremental ingestion and compact, clean text"),
        @("S3 Vectors", "USD 0.06/GB-month storage; USD 0.20/GB PUT; USD 2.50/M queries plus processing", "<USD 0.01", "~USD 0.25-1.00", "256 dimensions; avoid unnecessary metadata/results"),
        @("Lambda", "Requests plus GB-seconds; free tier may include 1M requests/400K GB-s", "~USD 0.00-0.03", "~USD 2.50", "Right-size memory and timeout; avoid provisioned concurrency without evidence"),
        @("API Gateway HTTP API", "Approximately USD 1/M requests in first tier; current free credits/tiers vary", "~USD 0.00-0.01", "~USD 0.20", "HTTP API and bounded payloads"),
        @("DynamoDB on-demand", "USD 0.625/M writes, USD 0.125/M reads in current us-east-1 example; storage", "<USD 0.01", "~USD 0.15-0.50", "TTL, on-demand, bounded messages"),
        @("S3 general purpose", "Storage, PUT/GET, versions", "<USD 0.05", "~USD 0.10-0.50", "30-day noncurrent lifecycle; delete demo when unused"),
        @("CloudFront", "Price Class 100 transfer and requests; flat/free plans require eligibility/enrollment", "~USD 0.09", "~USD 4-5", "Cache static assets and compress"),
        @("SQS", "Requests; 1M-request free tier commonly available", "~USD 0", "<USD 0.10", "Batch 100 events / 60 seconds"),
        @("CloudWatch", "Log ingestion/storage and alarm metrics", "~USD 0-0.70", "~USD 1-3", "Seven-day retention; avoid verbose payload logging"),
        @("SNS", "USD 0.50/M requests and email deliveries after free allowances", "~USD 0", "<USD 0.05", "Single topic and actionable alarm volume"),
        @("AWS Budget", "Standard budget pricing/free allowance depends on account", "~USD 0", "~USD 0", "Keep one project budget; add anomaly detection"),
        @("Estimated total", "Directional; retrieval/model dominate", "~USD 2-3/month", "~USD 120-125/month", "Measure actual token/retrieval usage and revise forecast")
    )
    Add-Heading 2 "14.2 Free Tier and Cost Categories"
    Add-Table -Caption "Cost category interpretation" -Headers @("Category", "Treatment") -Rows @(
        @("Always free", "No component is assumed always free. Service terms may change."),
        @("AWS Free Tier / credits", "Lambda, API Gateway, DynamoDB, SNS, CloudFront, and SQS may have allowances or credits; eligibility is account-specific."),
        @("Pay as you go", "Bedrock inference/retrieval/embeddings, S3 Vectors, data transfer, storage, requests, logs, and alarms."),
        @("Development estimate", "Small corpus and 1,000 questions; destroy when not actively demonstrated."),
        @("Production estimate", "Illustrative only; authentication/WAF/backup/audit hardening would add cost.")
    )
    Add-Heading 2 "14.3 Cost Optimization Recommendations"
    Add-Bullets @(
        "Retain Nova Micro only if a representative evaluation confirms answer quality; model size is the primary inference lever.",
        "Track average prompt/history/output tokens and standard retrieval call count as business KPIs.",
        "Keep history and retrieval result limits bounded; prevent automated clients from retrying unboundedly.",
        "Use S3 lifecycle rules, short log retention, DynamoDB TTL, and prompt demo destruction.",
        "Do not add NAT Gateway, OpenSearch capacity, provisioned Bedrock throughput, or provisioned concurrency without measured demand.",
        "Savings Plans and Reserved Instances do not apply meaningfully to the current serverless footprint; DynamoDB Database Savings Plans become relevant only at sustained scale.",
        "Spot capacity is not applicable because no EC2/ECS/EKS compute exists."
    )

    Add-Heading 1 "15 Design Decisions"
    Add-Table -Caption "Architecture decision record summary" -Headers @("Decision", "Reason", "Alternatives / trade-off", "Future trigger") -Rows @(
        @("Serverless managed architecture", "Low idle cost and operations", "Less low-level control than containers/EC2", "Move only for demonstrated runtime/network need"),
        @("S3 Vectors", "No continuously running vector cluster", "Semantic-only retrieval and metadata constraints", "Hybrid search or advanced ranking requirement"),
        @("Nova Micro", "Low-cost text generation", "Potential quality gap versus larger models", "Formal evaluation shows unacceptable accuracy"),
        @("Titan V2 at 256 dimensions", "Compact vectors and supported retrieval use", "May reduce recall versus larger dimensions", "Quality benchmark justifies re-indexing"),
        @("RetrieveAndGenerate", "Managed citations and less orchestration code", "Less control; one AWS action cannot be resource scoped", "Need custom retrieval/reranking/caching"),
        @("DynamoDB TTL sessions", "Serverless keyed history with natural expiry", "Anonymous and non-transactional pair writes", "Authenticated cross-device history"),
        @("Plain browser frontend", "No build/dependency pipeline", "Manual component architecture", "Complex UI warrants a framework"),
        @("CloudFront plus private S3", "Private origin and managed HTTPS", "Default domain/certificate", "Custom branded domain and TLS policy"),
        @("No VPC/NAT", "No private dependency; avoids fixed cost", "Cannot directly access private-only systems", "Enterprise network integration requirement"),
        @("Separate bootstrap root", "Solves backend bootstrap and preserves identities", "Two Terraform lifecycles", "Central platform team manages shared foundation"),
        @("Exact binary-plan promotion", "Deployment matches reviewed change", "Artifact/toolchain coupling and extra metadata", "Managed policy platform provides equivalent guarantees"),
        @("No GitHub Environments", "User preference; fewer configuration objects", "No environment approval gate", "Governance mandates independent deployment approvers"),
        @("No containers/images", "Lambda ZIP/static assets are the real runtime formats", "No portable container artifact", "Runtime dependencies exceed ZIP/Lambda constraints")
    )

    Add-Heading 1 "16 Best Practices Followed"
    Add-Table -Caption "Best-practice implementation" -Headers @("Area", "Practices") -Rows @(
        @("Terraform", "Remote versioned encrypted state; native locking; validated variables; exact plans; provider lock and artifact checksums; separate bootstrap."),
        @("AWS", "Managed serverless services; service-specific roles; private storage; throttling; TTL/lifecycle; short logs; mandatory budget."),
        @("GitHub", "Feature branches, PR checks, protected main, OIDC, fork isolation, minimal permissions, concurrency controls."),
        @("CI/CD", "Path-aware analysis, reproducible tool versions, immutable promotion artifacts, fail-closed verification, controlled destroy."),
        @("Security", "Least privilege, TLS, encryption, CSP/security headers, no stored AWS keys, secret/variable separation, layered scanning."),
        @("Application", "Input validation, bounded work, structured errors/logs, grounding fallback, citation sanitization, responsive accessible UI."),
        @("Observability", "Service logs, concise structured fields, error-rate/queue/API/database alarms, SNS and budget notification."),
        @("Cost", "No NAT/cluster/always-on vector service; on-demand capacity; small model/dimensions; lifecycle and retention controls."),
        @("Containers", "Not applicable; avoiding an unused image pipeline is itself supply-chain simplification.")
    )

    Add-Heading 1 "17 Known Limitations"
    Add-Table -Caption "Limitations, risks, and mitigations" -Headers @("Limitation / risk", "Impact", "Current mitigation", "Recommended enhancement") -Rows @(
        @("Unauthenticated public API", "Abuse, cost, session disclosure", "Throttle, limits, alarms, budget", "JWT/Cognito, WAF, per-user authorization"),
        @("Browser-local session index", "No cross-device discovery; local deletion loses navigation", "DynamoDB retains messages until TTL", "Authenticated server-side conversation catalogue"),
        @("UUID is not identity", "Possession permits history read", "Short TTL; no sensitive corpus intended", "Bind session to authenticated subject"),
        @("Non-transactional paired writes", "Partial turn possible", "Batch writer and simple schema", "Transactional turn record or status field"),
        @("Eventual ingestion", "New content not immediately answerable", "SQS retry and logs", "Poll job status and expose operational readiness"),
        @("Small demo corpus", "Answer quality is not representative", "Strict insufficient-information fallback", "Curated corpus and formal RAG evaluation"),
        @("No Guardrails", "No managed safety/PII policy", "Grounding prompt and input bounds", "Bedrock Guardrails plus content policy"),
        @("No WAF/custom domain", "Limited edge abuse control and branding", "CloudFront headers and API throttling", "WAF, ACM, Route 53, modern TLS policy"),
        @("Single Region", "Regional outage affects service", "Managed multi-AZ services", "Defined RTO/RPO and multi-Region pattern if required"),
        @("No PITR/backup for sessions", "History is disposable", "24-hour TTL by design", "Enable PITR only for durable authenticated history"),
        @("No dashboard/tracing/canary", "Slower diagnosis and no end-to-end SLO", "Logs and five alarms", "CloudWatch dashboard, X-Ray, synthetics, SLOs"),
        @("Default CloudFront certificate", "TLS policy is provider controlled", "HTTPS/HSTS", "Custom domain and ACM"),
        @("Terraform binary portability", "Plans tied to toolchain/environment", "Exact metadata verification", "Regenerate and review when expired or incompatible")
    )

    Add-Heading 1 "18 Conclusion"
    Add-Paragraph "Chatbot-Bedrock implements a coherent low-cost AWS-native RAG demonstration using managed services, private object storage, short-lived serverless compute, semantic vector retrieval, and reviewable infrastructure automation. The architecture scales with request volume without idle application servers and keeps operational scope intentionally small."
    Add-Paragraph "Maintainability is supported by a single understandable application Terraform root, a separate protected bootstrap lifecycle, narrowly scoped IAM responsibilities, two clear GitHub workflows, automated source/IaC security checks, structured logs, alarms, and a cost budget. Exact reviewed-plan promotion provides strong traceability between pull-request review and deployment."
    Add-Paragraph "The primary roadmap is not more infrastructure; it is production control: authenticate users, authorize session data, add WAF and Guardrails, define audit/retention requirements, establish RAG quality evaluation, add canary/SLO monitoring, and validate recovery objectives. Until those controls exist, the system should remain a controlled demonstration with conservative throttles and active cost monitoring."

    Add-Heading 1 "Appendix A - Repository Structure"
    Add-Table -Caption "Repository directory responsibilities" -Headers @("Path", "Responsibility") -Rows @(
        @(".github/workflows/application.yml", "Application tests, SAST, SCA, SonarCloud, and Snyk orchestration."),
        @(".github/workflows/terraform.yml", "Declarative plan/apply/destroy workflow; no top-level scripts."),
        @(".github/actions/terraform-plan", "Formatting, initialization, validation, Trivy, plan, checksums, and artifact upload."),
        @(".github/actions/terraform-promote", "Artifact discovery, provenance/checksum verification, and exact plan apply."),
        @("bootstrap/", "Local-only state bucket and GitHub OIDC role lifecycle."),
        @("terraform/", "Application AWS resources, packaging, variables, and outputs."),
        @("frontend/", "Static browser application and API configuration template."),
        @("lambdas/chat/", "HTTP RAG and session handler."),
        @("lambdas/ingestion/", "SQS-driven Bedrock ingestion starter."),
        @("documents/", "Repository-authored knowledge-base corpus."),
        @("tests/", "Chat, ingestion, and frontend unit/static tests."),
        @("docs/", "Architecture, plans, decisions, risks, IAM matrix, and this SDD."),
        @("scripts/smoke-test.sh", "Post-deployment endpoint smoke checks."),
        @("scripts/generate-sdd.ps1", "Reproducible native Word document generator.")
    )

    Add-Heading 1 "Appendix B - Environment Variables and Repository Configuration"
    Add-Table -Caption "Lambda environment variables" -Headers @("Variable", "Function", "Purpose", "Sensitive") -Rows @(
        @("TABLE_NAME", "Chat", "DynamoDB session table name", "No"),
        @("KNOWLEDGE_BASE_ID", "Chat / ingestion", "Bedrock Knowledge Base identifier", "No"),
        @("GENERATION_MODEL_ARN", "Chat", "Selected Nova model/inference profile ARN", "No"),
        @("GENERATION_MODEL_ID", "Chat", "Informational model identifier", "No"),
        @("SESSION_TTL_SECONDS", "Chat", "Message expiration interval", "No"),
        @("MAX_MESSAGE_LENGTH", "Chat", "Maximum input and context fragment length", "No"),
        @("MAX_HISTORY_MESSAGES", "Chat", "Bounded context message count", "No"),
        @("MAX_HISTORY_RESPONSE_MESSAGES", "Chat", "History API response limit", "No"),
        @("MAX_CITATIONS", "Chat", "Maximum returned citations", "No"),
        @("DATA_SOURCE_ID", "Ingestion", "Bedrock data-source identifier", "No"),
        @("LOG_LEVEL", "Both", "Python logging threshold", "No")
    )
    Add-Table -Caption "GitHub Variables and Secrets" -Headers @("Name", "Type", "Purpose") -Rows @(
        @("AWS_PLAN_ROLE_ARN", "Variable", "Read-oriented plan role"),
        @("AWS_DEPLOY_ROLE_ARN", "Variable", "Main-only deployment role"),
        @("AWS_REGION", "Variable", "AWS and backend Region"),
        @("TERRAFORM_VERSION", "Variable", "Exact Terraform CLI version"),
        @("TF_BACKEND_BUCKET", "Variable", "Existing state bucket"),
        @("TF_STATE_KEY", "Variable", "Exact state object key"),
        @("TFVARS_FILE", "Variable", "Committed non-secret variable file"),
        @("SNYK_ORG", "Variable", "Snyk organization slug"),
        @("SONAR_ORGANIZATION", "Variable", "SonarCloud organization key"),
        @("SONAR_PROJECT_KEY", "Variable", "SonarCloud project key"),
        @("SNYK_TOKEN", "Secret", "Snyk CLI authentication"),
        @("SONAR_TOKEN", "Secret", "SonarCloud analysis authentication")
    )

    Add-Heading 1 "Appendix C - Terraform Variables"
    Add-Table -Caption "Application Terraform variables" -Headers @("Variable", "Default", "Purpose / constraint") -Rows @(
        @("project_name", "bedrock-rag-demo", "3-25 lowercase letters, digits, or hyphens"),
        @("environment", "demo", "2-12 lowercase letters, digits, or hyphens"),
        @("aws_region", "us-east-1", "Revalidate Bedrock/S3 Vectors before changing"),
        @("generation_model_id", "amazon.nova-micro-v1:0", "Generation model stored in SSM"),
        @("generation_model_arn_override", "null", "Optional inference-profile/model ARN"),
        @("embedding_model_id", "amazon.titan-embed-text-v2:0", "Embedding model"),
        @("embedding_dimensions", "256", "Allowed 256, 512, 1024; must match index/model"),
        @("session_retention_hours", "24", "Allowed 1-720 hours"),
        @("monthly_budget_usd", "10", "Mandatory budget, minimum USD 1"),
        @("alert_email", "null", "Optional confirmed SNS email"),
        @("log_retention_days", "7", "Allowed cost-conscious retention list"),
        @("lambda_error_rate_threshold", "5", "Chat error percentage alarm"),
        @("api_5xx_threshold", "3", "API 5xx alarm count"),
        @("dynamodb_throttle_threshold", "1", "Table throttling alarm"),
        @("api_throttle_rate", "5", "Sustained HTTP API request rate"),
        @("api_throttle_burst", "10", "HTTP API burst"),
        @("force_destroy_buckets", "true", "Demo teardown behavior; review before production"),
        @("additional_tags", "{}", "Additional supported resource tags")
    )
    Add-Table -Caption "Bootstrap Terraform variables" -Headers @("Variable", "Default / source", "Purpose") -Rows @(
        @("aws_region", "us-east-1", "State bucket and policy Region"),
        @("state_bucket_name", "Required unique value", "Dedicated remote-state bucket"),
        @("state_key", "bedrock-rag-demo/demo/terraform.tfstate", "Application state object"),
        @("github_owner / repository", "Elzabeth-L / Chatbot-Bedrock", "OIDC repository identity"),
        @("github_owner_id / repository_id", "Immutable IDs in bootstrap config", "Transfer-resistant OIDC subject"),
        @("feature_branch", "feature/initial-bedrock-rag", "Explicit branch trusted by plan role"),
        @("tags", "Project/ManagedBy/Purpose", "Bootstrap resource metadata")
    )

    Add-Heading 1 "Appendix D - Workflow Files and Trigger Matrix"
    Add-Table -Caption "Workflow trigger matrix" -Headers @("Workflow", "Pull request", "Push to main", "Manual") -Rows @(
        @("Application CI", "Always reports; analyses only application-relevant changes", "Only application/test/dependency/scan paths", "Runs complete suite"),
        @("Terraform", "Same-repository plan only", "Plan for terraform/frontend/lambda/document/workflow/backend paths", "Plan changes, apply reviewed changes, plan destruction, apply reviewed destruction")
    )
    Add-Paragraph "The composite action files contain shell and GitHub API implementation details. The top-level Terraform workflow contains only declarative uses steps, satisfying the project constraint that scripts not be embedded in the pipeline workflow."

    Add-Heading 1 "Appendix E - References"
    Add-Table -Caption "Authoritative references" -Headers @("Topic", "Reference") -Rows @(
        @("Amazon Bedrock pricing", "https://aws.amazon.com/bedrock/pricing/"),
        @("Amazon Nova cost optimization", "https://aws.amazon.com/blogs/machine-learning/effective-cost-optimization-strategies-for-amazon-bedrock/"),
        @("Titan Text Embeddings V2", "https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-titan-text-embeddings-v2.html"),
        @("S3 and S3 Vectors pricing", "https://aws.amazon.com/s3/pricing/"),
        @("API Gateway pricing", "https://aws.amazon.com/api-gateway/pricing/"),
        @("Lambda pricing", "https://aws.amazon.com/lambda/pricing/"),
        @("DynamoDB pricing", "https://aws.amazon.com/dynamodb/pricing/"),
        @("CloudWatch pricing", "https://aws.amazon.com/cloudwatch/pricing/"),
        @("SNS pricing", "https://aws.amazon.com/sns/pricing/"),
        @("Terraform S3 backend", "https://developer.hashicorp.com/terraform/language/backend/s3"),
        @("Knowledge Base supported models", "https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base-supported.html"),
        @("S3 Vectors and Bedrock", "https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-vectors-bedrock-kb.html"),
        @("Repository", "https://github.com/Elzabeth-L/Chatbot-Bedrock")
    )

    Add-Heading 1 "Appendix F - Glossary"
    Add-Table -Caption "Glossary" -Headers @("Term", "Definition") -Rows @(
        @("Grounding", "Restricting generated claims to facts supported by retrieved sources."),
        @("Ingestion", "Parsing, chunking, embedding, and indexing source documents for retrieval."),
        @("Knowledge Base", "Bedrock-managed configuration connecting a data source, embedding model, and vector store."),
        @("Plan promotion", "Applying the exact previously generated and reviewed Terraform binary plan."),
        @("Session registry", "Browser-local list of anonymous session IDs, display titles, and timestamps."),
        @("Vector embedding", "Numeric representation of text used for semantic similarity search."),
        @("Workload identity", "Short-lived identity derived from an external workload token instead of a stored credential.")
    )

    Add-Heading 1 "Appendix G - Acronyms"
    Add-Table -Caption "Acronyms" -Headers @("Acronym", "Meaning") -Rows @(
        @("ACM", "AWS Certificate Manager"),
        @("API", "Application Programming Interface"),
        @("CI/CD", "Continuous Integration / Continuous Delivery"),
        @("CSP", "Content Security Policy"),
        @("DLQ", "Dead-Letter Queue"),
        @("HSTS", "HTTP Strict Transport Security"),
        @("IaC", "Infrastructure as Code"),
        @("IAM", "Identity and Access Management"),
        @("OIDC", "OpenID Connect"),
        @("OAC", "Origin Access Control"),
        @("RAG", "Retrieval-Augmented Generation"),
        @("RPO", "Recovery Point Objective"),
        @("RTO", "Recovery Time Objective"),
        @("SAST", "Static Application Security Testing"),
        @("SCA", "Software Composition Analysis"),
        @("SDD", "Solution Design Document"),
        @("SSE", "Server-Side Encryption"),
        @("TTL", "Time to Live"),
        @("WAF", "Web Application Firewall")
    )

    # Headers and footers
    foreach ($section in $document.Sections) {
        $header = $section.Headers.Item(1).Range
        $header.Text = "CHATBOT-BEDROCK  |  SOLUTION DESIGN DOCUMENT"
        $header.Font.Name = "Aptos"
        $header.Font.Size = 8
        $header.Font.Color = 0x666666
        $header.ParagraphFormat.Alignment = $wdAlignRight
        $header.Borders.Item($wdBorderBottom).LineStyle = 1
        $header.Borders.Item($wdBorderBottom).Color = 0xB5C7B8

        $footer = $section.Footers.Item(1).Range
        $footer.Text = "Confidential  |  Version $version  |  $documentDate  |  Page "
        $footer.Font.Name = "Aptos"
        $footer.Font.Size = 8
        $footer.Font.Color = 0x666666
        $footer.ParagraphFormat.Alignment = $wdAlignCenter
        $footer.Collapse($wdCollapseEnd)
        $null = $document.Fields.Add($footer, $wdFieldPage)
    }

    # Refresh dynamic structures and save as native Word document.
    $word.Options.Pagination = $true
    foreach ($field in $document.Fields) { $null = $field.Update() }
    foreach ($toc in $document.TablesOfContents) { $null = $toc.Update() }
    $document.Repaginate()
    $document.SaveAs2($outputPath, 16)
    $pageCount = $document.ComputeStatistics(2)
    $wordCount = $document.ComputeStatistics(0)
    Write-Output "output=$outputPath"
    Write-Output "pages=$pageCount"
    Write-Output "words=$wordCount"
    Write-Output "tables=$($document.Tables.Count)"
} finally {
    if ($document) { $document.Close($false) }
    if ($word) { $word.Quit() }
    if ($document) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($document) }
    if ($word) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word) }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
