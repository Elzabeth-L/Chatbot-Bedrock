# Implementation planning index

Status: approved baseline for implementation  
Decision date: 2026-07-28

This directory is intentionally created before application or infrastructure code. It
captures the architecture and constraints that implementation must follow.

- [Implementation plan](implementation-plan.md)
- [Architecture and flows](architecture.md)
- [Technology decisions](technology-decisions.md)
- [Repository structure](repository-structure.md)
- [IAM responsibility matrix](iam-matrix.md)
- [Assumptions, risks, and limitations](assumptions-risks.md)

Material deviations discovered during implementation must be recorded in these
documents and summarized in the root README.

## Enterprise deliverable

- `Chatbot-Bedrock-Solution-Design-Document.docx` is the formal architecture,
  implementation, CI/CD, deployment, operations, security, and cost document.
- Regenerate it on Windows with
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/generate-sdd.ps1`.
  The entry point uses direct Office Open XML packaging, requires no administrator
  access or additional software, and leaves no temporary build directory.

## RAG runtime workflow

- **Titan Text Embeddings V2:** Converts document chunks and questions into numerical vectors.
- **S3 Vectors:** Stores vectors and finds semantically similar document chunks.
- **Bedrock Knowledge Base:** Coordinates document ingestion, embeddings, vector retrieval, and source metadata.
- **Nova Micro:** Generates the natural-language answer using the retrieved chunks.
- **Chat Lambda:** Validates requests, supplies history, invokes Bedrock, checks citations, stores the conversation, and returns the response.
- **DynamoDB:** Stores temporary conversation messages.
- **Document S3 bucket:** Stores original knowledge documents.
- **Frontend S3 bucket:** Stores the website.
- **Terraform-state S3 bucket:** Stores Terraform state only; it is unrelated to chatbot retrieval.

```text
Browser
   │
   │ HTTPS POST /chat
   ▼
API Gateway
   │
   │ Invokes the deployed chat Lambda
   ▼
Chat Lambda
   │
   ├── Validates the request
   ├── Loads conversation context from DynamoDB
   └── Calls Bedrock RetrieveAndGenerate
                │
                ▼
       Bedrock Knowledge Base
                │
                ├── Embeds the question with Titan V2
                ├── Searches S3 Vectors
                └── Retrieves relevant document chunks
                               │
                               ▼
                         Nova Micro
                               │
                               ├── Receives retrieved text
                               ├── Receives grounding instructions
                               └── Generates an answer
                │
                ▼
          Answer + citations
                │
                ▼
           Chat Lambda
                │
                ├── Checks answer and citations
                ├── Stores the turn in DynamoDB
                └── Returns JSON through API Gateway
                               │
                               ▼
                            Browser
```
