# Intended repository structure

```text
.
|-- .github/
|   |-- actions/
|   |   |-- terraform-plan/
|   |   `-- terraform-promote/
|   `-- workflows/
|       |-- application.yml
|       `-- terraform.yml
|-- docs/
|-- documents/
|   |-- terraform-basics.md
|   `-- kubernetes-basics.md
|-- frontend/
|   |-- config.js.tftpl
|   |-- index.html
|   |-- styles.css
|   `-- app.js
|-- lambdas/
|   |-- chat/
|   |   |-- handler.py
|   |   `-- requirements.txt
|   `-- ingestion/
|       |-- handler.py
|       `-- requirements.txt
|-- scripts/
|   `-- smoke-test.sh
|-- tests/
|   |-- chat/
|   `-- ingestion/
|-- terraform/
|   |-- backend.tf
|   |-- data.tf
|   |-- iam.tf
|   |-- knowledge_base.tf
|   |-- lambdas.tf
|   |-- api.tf
|   |-- storage.tf
|   |-- frontend.tf
|   |-- monitoring.tf
|   |-- budget.tf
|   |-- variables.tf
|   |-- locals.tf
|   |-- outputs.tf
|   `-- versions.tf
|-- backend.hcl.example
|-- terraform.tfvars.example
|-- pyproject.toml
|-- .gitignore
`-- README.md
```

This uses one small Terraform root module. Splitting every service into a module
would obscure cross-resource policies and dependencies without providing meaningful
reuse.
