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
