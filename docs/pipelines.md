# GitHub Actions deployment runbook

Three independent workflows validate pull requests and deploy only through a
manual **Run workflow** on `main`. No push triggers deployment. Deployments use
Azure OIDC, SHA-pinned actions, job timeouts, and workflow concurrency. Configure
the controls below before the first deployment run; workflow files cannot create
GitHub environment reviewers or Azure federated credentials themselves.

Terraform currently validates and plans only: its apply job is unconditionally
disabled. Function App and hosted agent deployment workflows are unchanged.

## Active deployment target

The workflows currently target the existing POC resources in resource group `test`.
Use the existing backend key `agentic-sre/poc.tfstate` and the existing POC variable values.
The separate `environments/prod` root is reserved for a future production rollout.
Terraform automatically loads the versioned `environments/poc/terraform.tfvars`.
It contains non-secret POC values; the example is only a field reference.

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

## 1. Terraform POC

Workflow: `.github/workflows/terraform.yml`.
Root: `environments/poc`, reusing the existing modules. The workflow uses the existing POC
provider lock file and backend. A future production rollout must use a distinct state key. The
production composition mirrors POC; keep shared infrastructure changes in `modules/` and
review changes to both root compositions together.

The lock files must contain hashes for the Linux CI runner as well as Windows
development. After changing provider versions, run this from each affected root
and commit the resulting lock file:

```powershell
terraform providers lock -platform=linux_amd64 -platform=windows_amd64
```

CI deliberately keeps `-lockfile=readonly` so dependency changes require review.

Set these variables identically in **both** Terraform environments:

| Variable | Purpose |
|---|---|
| `TF_STATE_RESOURCE_GROUP` | Bootstrapped state resource group |
| `TF_STATE_STORAGE_ACCOUNT` | Dedicated state storage account |
| `TF_STATE_CONTAINER` | Existing private blob container |
| `TF_STATE_KEY` | Existing POC key: `agentic-sre/poc.tfstate` |

Use Entra access to state; disable anonymous access, enable blob versioning and
soft delete, and restrict state access to the deployment identities/operators.
If state is private, replace `ubuntu-24.04` with a trusted runner that has the
required network path. A future production environment must not share POC state.

Review changes to `environments/poc/terraform.tfvars` in source control. Retain
the existing names, subscription/tenant IDs, Windows Function OS, consumer group,
model, project endpoint, database administrator, and reviewed firewall rules.
Keep credentials and secrets out of this file. `TFVARS_JSON` is no longer used
by the workflow. The example is not an import-ready configuration. The plan job
checks that the POC tenant/subscription match its configured Azure identity.

Set the same strong random `TF_PLAN_KEY` **secret** in both Terraform
environments. For example, generate one offline with `openssl rand -base64 48`.
This encrypts the saved plan before artifact upload. Only the encrypted plan is
retained, for one day; do not rotate this key between plan and apply jobs.

Run the workflow on `main`. It validates, initializes the OIDC backend, locks
state, creates a saved plan, summarizes action counts, and rejects resource
deletes/replacements unless `allow_deletions` was explicitly selected. Review
the complete plan in the plan job log. The apply job always skips, including
when changes are detected. Re-enabling it requires a reviewed workflow change
to restore its condition to `needs.plan.outputs.changes == '2'`. When enabled,
apply downloads the artifact from that same run, verifies its decrypted SHA256,
and applies that exact saved plan without replanning after environment approval.
Drift that makes the plan stale must result in a fresh run and fresh review.

For existing resources, import them through a reviewed operator process before
running this workflow. The existing POC import script targets POC and must not
be used against production. There is no destroy or automatic import pipeline.

The production root does not itself complete private networking, Key Vault,
Foundry project creation, Easy Auth configuration, or database migrations.
These are existing infrastructure gaps; the pipeline does not make the current
infrastructure production-ready by itself. Review availability, backups,
public access, and identity settings in production variables before applying.

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
