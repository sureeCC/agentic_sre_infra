# Agentic SRE deployment

This repository contains application code and Terragrunt deployment configuration. Reusable Terraform modules live in the private [agentic_sre_modules repository](https://github.com/sureeCC/agentic_sre_modules), pinned by the GitHub `MODULE_REF` variable.

```text
.github/workflows/        Infrastructure, formatting and application workflows
applications/            Function alert bridge and Foundry hosted agent
live/                    Shared HCL and six resource-level Terragrunt units
scripts/ci/              Active pipeline helpers
docs/                   Infrastructure setup and application deployment runbook
```

Run **Agentic SRE infrastructure** from `main`, select the environment and one unit or `all`, then choose `plan`, `apply` or `destroy`. Validation and planning precede execution. Each unit/environment has a separate Azure Blob state file. Authentication uses OIDC with a managed identity.

Read [infrastructure setup](docs/INFRASTRUCTURE-SETUP.md) for variables, secrets, naming, state and local commands. Read [application pipelines](docs/pipelines.md) before deploying applications. Application hosting, permissions, private DNS and database Entra configuration are separate prerequisites; the six infrastructure units do not provision Function hosting.

After a destroy, Foundry and Key Vault names may remain reserved by soft-deleted resources. Reconcile or recover those resources before attempting to reuse their names. This repository currently uses the modules' default provider deletion behavior.