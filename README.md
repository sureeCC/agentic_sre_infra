# Agentic SRE Terraform

## Terragrunt configuration

A separate [Terragrunt layout](terragrunt/README.md) provides shared root/common
configuration and one unit per existing module for POC and production. Read its
state ownership migration instructions before using it for existing resources.

## CI/CD pipelines

Three independent GitHub Actions workflows are available for controlled POC
Terraform plan/apply, Function App deployment, and Foundry hosted-agent
deployment. See [the setup and deployment runbook](docs/pipelines.md) for OIDC,
protected environments, required variables/secrets, and deployment order.

This directory is the infrastructure-as-code foundation for the production-grade
Kibana -> Azure Functions -> Event Hubs -> Foundry Hosted Agent -> PostgreSQL
architecture.

## Delivery order

Build and review one layer at a time. Do not apply an unreviewed, all-in-one
deployment.

1. Bootstrap a dedicated Terraform state storage account and configure remote state.
2. Create a tagged resource group with the `resource-group` module.
3. Add Key Vault, private networking, diagnostics, and role assignments.
4. Add Event Hubs and its consumer group. **Implemented, pending review/import.**
5. Add Function hosting, storage, managed identity, and application settings. **Implemented, pending review/import.**
6. Add PostgreSQL Flexible Server with Entra-only authentication. **Implemented, pending review/import.** Private access is the next hardening layer.
7. Add Foundry resource and model deployment. **Implemented, pending review/import.** Hosted Agent deployment remains a controlled application step.
8. Import existing POC resources before Terraform takes ownership; never recreate a live resource accidentally.

## State and identity

Use a separate Azure subscription/resource group for Terraform state. The backend
must use Microsoft Entra ID / OIDC authentication, not a storage account key.

Copy `backend.hcl.example` to a secure location outside source control, populate
the real state values, and initialize with:

```powershell
Push-Location .\terraform\environments\poc
terraform init -backend-config=..\..\backend.hcl
Pop-Location
```

The reviewed, non-secret `environments/poc/terraform.tfvars` is versioned and
automatically loaded by Terraform. Other tfvars files remain ignored by default.
Do not commit `backend.hcl`, client secrets, Event Hubs SAS keys, database
passwords, or secrets in variable files. The target runtime design uses managed
identities instead. The GitHub Actions Terraform apply job is currently disabled;
manual workflow runs validate and plan only.

## Local workflow

```powershell
Push-Location .\terraform
terraform fmt -recursive
Set-Location .\environments\poc
terraform init -backend=false
terraform validate
# A real plan needs the configured remote backend. Terraform automatically
# loads terraform.tfvars, so do not pass -var-file for that default file.
terraform init -reconfigure -backend-config=..\..\backend.hcl
terraform plan
Pop-Location
```

Use `-backend=false` only for syntax and module validation. Use the approved
remote backend before a real plan or apply.

## Existing POC migration

The current POC resource group is named `test`. Do not run an apply that creates
a second copy of existing resources. Each production module will include a
resource-import runbook. For example, after the Resource Group module has been
reviewed:

```powershell
Push-Location .\terraform\environments\poc
terraform import `
  module.resource_group.azurerm_resource_group.this `
  /subscriptions/<subscription-id>/resourceGroups/test
Pop-Location
```

Run an import only after the values in `terraform.tfvars` exactly match the
existing Azure resource.

## First implemented layer

`modules/resource-group` implements the Azure Resource Group boundary with
mandatory environment, workload, owner, cost-centre, and data-classification
tags.

`modules/event-hubs` implements an Event Hubs namespace, named Event Hubs, and
explicit consumer groups. It enforces TLS 1.2 and disables local SAS
authentication by default. Diagnostics can be sent to Log Analytics when a
workspace ID is supplied. Keep public network access enabled until private
endpoints and private DNS are deployed; disabling it earlier would break the
current public Function App connectivity.

`modules/function-app` implements Linux Premium Function hosting, host storage,
Application Insights, a system-assigned managed identity, and event-hub-scoped
Data Sender/Data Receiver role assignments. It intentionally does not configure
Entra ingress authentication yet: that configuration depends on the Key Vault
and Entra application-registration layer so that no OAuth provider secret is
hard-coded in Terraform.

`modules/app-registrations` creates the Entra Function API and Kibana
confidential-client registrations, the application-only `Kibana.Alert.Send`
role, and the client-to-API assignment. It intentionally does not create the
Kibana client secret: a Terraform-created secret is retained in state. Create
or rotate it through an approved secret lifecycle, then store the value only in
Kibana's encrypted connector configuration.

`modules/foundry` uses the current Azure AI Services / Microsoft Foundry
resource path (`kind = AIServices`) with Entra-only access and a system-assigned
identity. It can optionally deploy a model after regional availability and
quota are confirmed. Hosted Agents are deliberately not represented as a
generic Terraform resource yet; deploy the agent code after infrastructure is
created, then grant the agent identity its PostgreSQL permissions.

`modules/postgresql` provisions a PostgreSQL Flexible Server with Entra-only
authentication, an Entra administrator, the `agenticsre` database, backup
retention, optional diagnostics, and explicit temporary firewall rules. It does
not create database users, schemas, or tables: the GitHub Actions deployment
must run an idempotent SQL migration after the Hosted Agent identity exists.
