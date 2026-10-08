# Agentic SRE Terragrunt configuration

This folder follows the shared `root.hcl` / exposed `common.hcl` / resource
`terragrunt.hcl` pattern. It uses the six existing modules in `../modules`.
Each unit has a separate remote state key. The infrastructure workflow now uses
Terragrunt; the old Terraform environments remain references for state migration.

```text
terragrunt/
  root.hcl                     # Provider generation and Azure state backend
  environments/
    poc/                       # Existing reviewed POC settings
      common.hcl               # Module sources and shared tags
      resource-group/terragrunt.hcl
      event-hubs/terragrunt.hcl
      foundry/terragrunt.hcl
      function-app/terragrunt.hcl
      postgresql/terragrunt.hcl
      app-registrations/terragrunt.hcl
    prod/                      # Same six units, with example production settings
```

The Function module owns its storage account, service plan, Application Insights,
managed identity, and role assignments. Event Hubs owns namespaces, hubs,
consumer groups, and optional diagnostics. Foundry owns its resource and optional
model deployment. PostgreSQL owns its server, database, Entra administrator,
firewall rules, and optional diagnostics. Entra owns both app registrations,
service principals, the API role, and client assignment.

No additional resource modules are present for Key Vault, private networking,
central Log Analytics, or Logic Apps. Add units when those modules are available.
Hosted-agent deployment, Function code deployment, database schemas, and secret
rotation remain application delivery tasks described in the existing runbooks.

## Configure

Edit each resource's `terragrunt.hcl` to change its hardcoded `inputs`. Edit
`common.hcl` for shared subscription, tenant, location, resource group, and tag
values. POC matches the versioned `../environments/poc/terraform.tfvars`, including
the `test` resource group, Windows Y1 Function, Basic Event Hub, Foundry project,
Entra registrations, and PostgreSQL firewall rules. The Function's HTTP setting
is retained for adoption; enable `https_only` in both configurations after the
state migration is reviewed. Production resource names remain templates; replace
example names before planning. Production identity and endpoint values must be
supplied explicitly through the environment variables below.

```powershell
$env:TG_PROD_SUBSCRIPTION_ID = "<production-subscription-id>"
$env:TG_PROD_TENANT_ID = "<production-tenant-id>"
$env:TG_PROD_COST_CENTER = "<production-cost-center>"
$env:TG_PROD_POSTGRES_ADMIN_OBJECT_ID = "<database-admin-group-object-id>"
$env:TG_PROD_FOUNDRY_PROJECT_ENDPOINT = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$env:TG_PROD_FUNCTION_API_IDENTIFIER_URI = "api://<verified-production-api-uri>"
# Generate once, then retain the same role UUID across deployments.
$env:TG_PROD_KIBANA_ALERT_SEND_ROLE_ID = "<stable-app-role-uuid>"
$env:TG_PROD_POSTGRES_FIREWALL_RULES = '{"agent-egress":{"start_ip_address":"<approved-egress-ip>","end_ip_address":"<approved-egress-ip>"}}'
```

Use the hosted agent's actual egress path when reviewing database connectivity.
An empty firewall map blocks public clients; the current module has no private
endpoint or delegated subnet. Do not copy the broad POC Azure-services rule into
production. Review regional model availability and production networking.

Resource inputs include the existing Terraform environment defaults as explicit
values. The module inputs use the actual existing module interfaces, which differ
from unrelated Event Hub examples. Dependency-derived IDs and resource group
names continue to use upstream module outputs.

For example, `environments/poc/event-hubs/terragrunt.hcl` contains:

```hcl
inputs = {
  namespace_name = "pocagenticsre"
  sku            = "Basic"
  capacity       = 1
  location       = include.common.locals.location
  # Other inputs follow in the actual file.
}
```

For remote modules, change `iac_modules_repo` in each `common.hcl` to a Git source
such as `git::https://HOST/ORG/REPO.git` and set `module_ref` to a reviewed tag or
commit. Unit sources append `//MODULE?ref=REF`. Adjust module paths if the central
repository uses different directories. Local modules need no Git ref.

The backend defaults to your existing `test` resource group,
`sttfstateagenticsre244b` storage account, and `tfstate` container. Local POC
commands need no `TG_STATE_*` setup. Override these values for a different backend
or CI; select the reviewed production state account explicitly before production
initialization:

```powershell
$env:TG_STATE_RESOURCE_GROUP = "<state-resource-group>"
$env:TG_STATE_STORAGE_ACCOUNT = "<state-storage-account>"
$env:TG_STATE_CONTAINER = "tfstate"
$env:TG_TF_PATH = "terraform" # This project uses Terraform rather than OpenTofu.
# Set these when state lives in another subscription or tenant:
$env:TG_STATE_SUBSCRIPTION_ID = "<state-subscription-id>"
$env:TG_STATE_TENANT_ID = "<state-tenant-id>"
# Local runs use the authenticated Azure CLI session by default.
# For CI set TG_USE_OIDC=true and supply ARM_* OIDC identity variables.
```

The backend uses Entra authentication. `disable_init` prevents Terragrunt from
bootstrapping state storage; Terraform backend initialization still runs normally.
Keys use `agentic-sre/terragrunt/environments/ENV/UNIT/terraform.tfstate` and do
not reuse the combined Terraform environment state key.

## Ownership migration before planning existing resources

Do not apply these units against existing POC resources until state ownership
has been migrated. A new backend starts empty and would otherwise propose new
resources. Keep one owner per Azure resource and pause the old pipeline during
cutover. Back up state securely; state may contain secrets.

For every resource instance in the original state, transfer ownership using a
reviewed state migration or import into the matching new unit. Address mapping:

| Old address prefix | New unit | New address prefix |
| --- | --- | --- |
| `module.resource_group.` | `resource-group` | Remove module prefix |
| `module.event_hubs.` | `event-hubs` | Remove module prefix |
| `module.foundry.` | `foundry` | Remove module prefix |
| `module.function_app.` | `function-app` | Remove module prefix |
| `module.postgresql.` | `postgresql` | Remove module prefix |
| `module.app_registrations.` | `app-registrations` | Remove module prefix |

For example, the Resource Group becomes `azurerm_resource_group.this`:

```powershell
Set-Location ./terraform/terragrunt/environments/poc/resource-group
terragrunt init
terragrunt import azurerm_resource_group.this /subscriptions/<subscription-id>/resourceGroups/test
terragrunt plan
```

Imports do not remove ownership from the old state. Reconcile both states and
retire the old configuration/pipeline before applying either configuration.
Enumerate all managed resource instances, including role assignments, firewall
rules, consumer groups, and conditional Windows/Linux Function resources; do
not migrate only the top-level Azure services. Data sources refresh normally.

## Validate and review

In VS Code with `Agentic-SRE` open, use **Terminal > Run Task > Terragrunt:
validate POC**. This task selects the POC directory and the existing state
backend explicitly. **Terragrunt: check formatting** checks the entire layout.
Plain `terragrunt validate` runs one unit and must be executed inside that unit's
directory. The layout root and environment folders contain no `terragrunt.hcl`;
use `terragrunt run --all -- validate` from `environments/poc` to check its six
units. Running across both environments also requires the production variables.

Use the current Terragrunt CLI syntax documented by
[Terragrunt](https://docs.terragrunt.com/reference/cli/):

```powershell
Set-Location ./terraform/terragrunt
terragrunt hcl fmt --check --working-dir ./environments
# Offline checks use a temporary copy with synthetic dependency outputs.
./scripts/validate.ps1 -TerragruntPath terragrunt -TerraformPath terraform
Set-Location ./environments/poc/resource-group
terragrunt init
terragrunt validate
terragrunt plan
```

Migrate and review the Resource Group first, then Event Hubs, Foundry, PostgreSQL,
and Entra registrations; Function App depends on the Resource Group, Event Hubs,
and Foundry outputs. Dependency placeholders are allowed only for `validate`;
validation skips reading upstream outputs. Plans, applies, and normal renders
require real upstream state outputs.
After cutover, `terragrunt run --all -- plan` from an environment folder follows
the dependency graph. Review plans before any apply. This scaffolding does not
perform imports, state migration, or Azure deployment.

## Application delivery for this repository

Follow [the pipeline runbook](../docs/pipelines.md). The infrastructure workflow
validates all 12 units without Azure access on pushes and pull requests. Live POC
planning is a manual option after state migration; no apply job is enabled.

Before deploying the Function package, configure mandatory Entra Easy Auth with
the API client ID and audience from the `app-registrations` unit. The Function
authorizes the `Kibana.Alert.Send` role from Easy Auth's principal header; app
registrations alone do not enable Function authentication. The Function workflow
checks this prerequisite before deploying. Easy Auth settings and secrets remain
owned by the existing application delivery process.

Create or select the Foundry project and deploy `sre-alert-postgres-hosted` through
the hosted-agent workflow. The Foundry unit creates the AI Services account,
not the project or hosted agent. Supply the resulting project endpoint to the
Function. Configure `POSTGRES_HOST`, `POSTGRES_DATABASE`, and `POSTGRES_AAD_USER`
for the hosted agent, then bootstrap its Entra database role and grants as
described in [the agent README](../applications/foundry-hosted-alert-agent/README.md).

The validation script checks HCL rendering and module input contracts; it does
not validate provider schemas, Azure permissions, regional availability, runtime
authentication, or network connectivity. Real plans require the configured state
backend and upstream outputs. Local `.tools` files are ignored scratch artifacts;
the old `hardcode-inputs.ps1` conversion script refers to a retired layout and
must not be used to regenerate these files.
