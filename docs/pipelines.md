# GitHub Actions deployment runbook

Three independent workflows validate pull requests. Infrastructure validation also runs on pushes to main. Application workflows deploy only through a
manual **Run workflow** on `main`. No push triggers deployment. Deployments use
Azure OIDC, SHA-pinned actions, job timeouts, and workflow concurrency. Configure
the controls below before the first deployment run; workflow files cannot create
GitHub environment reviewers or Azure federated credentials themselves.

Terragrunt currently validates and optionally plans only; it has no apply job. Function App and hosted agent deployment workflows are unchanged.

## Active deployment target

The workflows target the existing POC resources in resource group `test`.
Infrastructure now uses `terragrunt/environments/poc`, with inputs in each unit's
`terragrunt.hcl` and shared values in `common.hcl`. CI does not load `.tfvars`.
The old combined state key `agentic-sre/poc.tfstate` must be migrated into six
unit states before live planning. See [Terragrunt migration instructions](../terragrunt/README.md).
Production receives offline validation only; its real rollout needs reviewed values.

## GitHub environments and Azure identities

Create `terraform-plan-poc`, `terraform-poc`, `function-poc`, and `agent-poc`.
Restrict all four to the protected `main` branch. Require deployment reviewers
on `terraform-poc`, `function-poc`, and `agent-poc`, and prevent self-review
and administrator bypass where supported by your GitHub plan. Protect `main`
with required pull-request reviews and the validation/build/package checks.
Keep plan access limited to trusted maintainers: Terraform plan logs can expose
configuration values that providers do not mark sensitive.

Use a different Entra application or user-assigned managed identity for each
environment, with one federated credential whose subject is:

```text
repo:sureeCC/agentic_sre_infra:environment:<environment-name>
```

Issuer: `https://token.actions.githubusercontent.com`.
Audience: `api://AzureADTokenExchange`.

Set these GitHub environment **variables** in all four environments:

| Variable | Value |
|---|---|
| `AZURE_CLIENT_ID` | That environment's deployment identity client ID |
| `AZURE_TENANT_ID` | Target tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Target subscription ID |

Grant only the required scopes. The plan identity needs resource read access,
Entra directory read access, and state-container Storage Blob Data Contributor
(Terraform state locking needs write access). The apply identity needs resource
management rights, scoped role-assignment rights, state access, and the Entra
application-management permissions required by `modules/app-registrations`.
Azure RBAC does not grant Microsoft Graph application permissions; an Entra
administrator must configure those separately. Function deployment needs
management/deployment access to the existing app, including auth/trigger reads.
Agent deployment needs the Foundry Project Manager role at the existing project
scope. Do not grant subscription-wide Owner to application deployers.

When `app_registration_manage_owners` is enabled, the module uses the planning
identity's object ID as owner. With separate plan/apply identities, explicitly
set it to `false` and manage owners through a reviewed Entra process, or give the
apply identity sufficient directory rights independently of ownership.

## 1. Terragrunt POC

Workflow: `.github/workflows/terraform.yml`, displayed as **Terragrunt POC**.
Terraform 1.9.8 executes beneath checksum-verified Terragrunt 1.1.6.

Pushes to `main`, relevant pull requests, and manual runs check HCL formatting
and all 12 POC/production units. Validation copies the configuration to a
temporary directory, uses synthetic dependency outputs, initializes providers
with `-backend=false -lockfile=readonly`, and runs `terragrunt validate`.
It needs no Azure login, remote state, or production variables. The normal unit
configuration permits placeholders only for validation, never live planning.
Each unit's committed lock file includes Windows and Linux provider checksums.
Update locks deliberately with `terragrunt providers lock
-platform=linux_amd64 -platform=windows_amd64` from each unit.

Set these variables in the existing **terraform-plan-poc** GitHub environment:

| Variable | Purpose |
|---|---|
| `AZURE_CLIENT_ID` | OIDC planning identity |
| `AZURE_TENANT_ID` | POC tenant |
| `AZURE_SUBSCRIPTION_ID` | POC subscription and state subscription |
| `TF_STATE_RESOURCE_GROUP` | Existing state resource group |
| `TF_STATE_STORAGE_ACCOUNT` | Existing state storage account |
| `TF_STATE_CONTAINER` | Existing state container |

The workflow maps existing `TF_STATE_*` variables to Terragrunt's `TG_STATE_*`
variables. `TF_STATE_KEY` and `TFVARS_JSON` are no longer used. State keys are
`agentic-sre/terragrunt/environments/poc/UNIT/terraform.tfstate`.
Set the `TF_PLAN_KEY` secret to encrypt saved plans before artifact upload.

To check CI before migration, push the change or manually run the workflow with
**run_plan unchecked**. To review a live plan, migrate ownership of every managed
resource instance, then run on `main` with **run_plan checked**. The plan job
uses OIDC, rejects unit states without managed resources, runs the six units in
dependency order, verifies the Azure tenant/subscription in each JSON plan, and
summarizes actions using the existing deletion policy. Nonempty state is an early
migration check, not proof that every resource was migrated; operators must
reconcile all resource instances against the original state.

Saved binary and JSON plans are encrypted and retained for one day. Plaintext
plans are removed afterward. There is no apply job, automatic import, or state
migration in this workflow. Do not run the old combined Terraform pipeline
against resources owned by the Terragrunt unit states. Re-enabling deployment
requires a reviewed change that applies the exact saved per-unit plans after
GitHub environment approval.

Private networking, Easy Auth, Foundry projects, and database role/bootstrap
steps remain prerequisites described in the Terragrunt and application runbooks.

## 2. Function App

Workflow: `.github/workflows/function-app.yml`.
In `function-poc`, set `AZURE_RESOURCE_GROUP` and `FUNCTION_APP_NAME`.

The build job publishes .NET 8 in Release mode and checks the Functions package.
After environment approval, the deploy job uses OIDC to deploy that exact build
artifact to the existing Function App. It requires enabled Entra App Service
Authentication with authentication mandatory before deployment, and verifies
that both expected Functions are registered afterward.

Configure Easy Auth's API audience/client and `Kibana.Alert.Send` assignment
before running. Retain the existing app settings: Event Hubs namespace, hub and
consumer group, Foundry project endpoint/name, runtime, and storage. This code
pipeline does not overwrite those settings. Terraform's Windows app ignores
app-setting drift; Linux does not, so app-setting ownership must be reviewed
when managing Linux apps. Validate the managed-identity Event Hubs and Foundry
permissions separately.

Deployment is directly to the production app. Slot promotion is not implemented
because the repo has no slot resources/settings, and an active staging Event
Hubs trigger could consume live alerts. A failed post-deployment check does not
automatically roll back. To roll back, revert the source change through review
and rerun on `main`; do not rerun an old Terraform apply job.

## 3. Foundry hosted agent

Workflow: `.github/workflows/ai-agent.yml`.
In `agent-poc`, set:

| Variable | Purpose |
|---|---|
| `FOUNDRY_PROJECT_ENDPOINT` | Existing HTTPS Foundry project endpoint |
| `FOUNDRY_AGENT_NAME` | Agent name matching the Function app setting |
| `AZURE_AI_MODEL_DEPLOYMENT_NAME` | Existing model deployment |
| `POSTGRES_HOST` | Production PostgreSQL hostname |
| `POSTGRES_DATABASE` | Application database |
| `POSTGRES_AAD_USER` | Provisioned agent Entra database role |
| `AGENT_CPU`, `AGENT_MEMORY` | Supported Foundry resource tier pair |

The package job checks dependency resolution/imports and Python syntax, then
builds a deterministic flat ZIP containing only `main.py` and `requirements.txt`.
After approval, the deploy job supplies environment-specific metadata, creates
the agent if absent or posts a new version if present, and polls that specific
version for up to 20 minutes. Failed or timed-out provisioning fails the job.
The summary records agent name, version, and source SHA256. Mutating requests
are not blindly retried after network errors; inspect Foundry before rerunning.

This uses Foundry's `remote_build` mode. Runtime dependencies currently have
unbounded versions in the source requirements, so remote builds are not fully
reproducible. Pin and validate runtime dependencies before a production release.
The identity created for the hosted agent needs an Entra PostgreSQL role and
table permissions. The `public.kibana_alerts` table must already exist; this
workflow does not create schema/users or grant database privileges. On a first
deployment, provision the agent identity's database access before enabling live
Function dispatch. Add an idempotency migration before relying on broad retries.

`active` verifies provisioning, not model inference or database persistence.
No automatic live alert is injected because that would write a production row.
Run a controlled end-to-end alert after database permissions and schema are
ready. Roll back by reverting code/metadata through review and deploying again.

## Deployment order and references

Bootstrap state and OIDC/GitHub controls; apply reviewed infrastructure; prepare
Foundry project/model and database schema; deploy agent and grant its database
access; configure Function ingress/app settings; deploy Function; run a
controlled end-to-end alert. The three workflows intentionally do not trigger
each other.

- [Azure Functions action](https://github.com/Azure/functions-action)
- [Terraform Azure backend and OIDC](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Foundry source-code deployment API](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/deploy-hosted-agent-code)
