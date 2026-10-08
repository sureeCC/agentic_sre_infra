# Agentic SRE Terragrunt

One Terragrunt stack manages all six resource modules in one Terraform state file
per environment. POC reuses the existing `agentic-sre/poc.tfstate` key. Production
uses `agentic-sre/prod.tfstate`; environments do not share resource ownership.

```text
terragrunt/
  root.hcl
  environments/
    poc/
      common.hcl
      terragrunt.hcl
      .terraform.lock.hcl
    prod/
      common.hcl
      terragrunt.hcl
      .terraform.lock.hcl
  scripts/validate.ps1
modules/agentic-sre-stack/
  main.tf
  variables.tf
  outputs.tf
```

The stack calls `resource-group`, `event-hubs`, `foundry`, `function-app`,
`postgresql`, and `app-registrations` directly. It preserves the existing
`module.resource_group.*`, `module.event_hubs.*`, `module.foundry.*`,
`module.function_app.*`, `module.postgresql.*`, and `module.app_registrations.*`
addresses. Terraform manages ordering between modules in the single graph.

## Existing POC state

The earlier split layout used empty per-unit states. No resource ownership was
migrated or infrastructure applied. This combined layout points directly to the
original backend, so no state split, address rewrite, or import is required when
that original state already owns the resources. Check the plan before applying.
Use only one infrastructure pipeline to manage this state.

## Configuration

Edit resource inputs in `environments/ENV/terragrunt.hcl` and shared subscription,
tenant, region, resource group, and tags in `common.hcl`. Shared values override
matching resource inputs. The POC values match the reviewed existing deployment.
The stack does not load `.tfvars` files. Keep module `variables.tf` files because
they define the Terraform interfaces.

The backend defaults to resource group `test`, storage account
`sttfstateagenticsre244b`, and container `tfstate`. Optional overrides:

```powershell
$env:TG_TF_PATH = "C:\terraform\terraform.exe"
$env:TG_STATE_RESOURCE_GROUP = "test"
$env:TG_STATE_STORAGE_ACCOUNT = "sttfstateagenticsre244b"
$env:TG_STATE_CONTAINER = "tfstate"
$env:TG_STATE_KEY = "agentic-sre/poc.tfstate"
# Use these if state is in another subscription/tenant:
$env:TG_STATE_SUBSCRIPTION_ID = "<state-subscription-id>"
$env:TG_STATE_TENANT_ID = "<state-tenant-id>"
```

Local backend authentication uses Azure CLI. CI sets `TG_USE_OIDC=true` and
supplies the `ARM_*` identity variables. State storage is bootstrapped separately.
Production resource names remain examples. Supply reviewed production values:

```powershell
$env:TG_PROD_SUBSCRIPTION_ID = "<production-subscription-id>"
$env:TG_PROD_TENANT_ID = "<production-tenant-id>"
$env:TG_PROD_COST_CENTER = "<production-cost-center>"
$env:TG_PROD_POSTGRES_ADMIN_OBJECT_ID = "<database-admin-group-object-id>"
$env:TG_PROD_FOUNDRY_PROJECT_ENDPOINT = "https://<resource>.services.ai.azure.com/api/projects/<project>"
$env:TG_PROD_FUNCTION_API_IDENTIFIER_URI = "api://<verified-api-uri>"
$env:TG_PROD_KIBANA_ALERT_SEND_ROLE_ID = "<stable-app-role-uuid>"
$env:TG_PROD_POSTGRES_FIREWALL_RULES = '{"agent-egress":{"start_ip_address":"<approved-egress-ip>","end_ip_address":"<approved-egress-ip>"}}'
```

Choose a production state account explicitly and unset or change `TG_STATE_KEY`
when switching environments. Never point production at the POC state key.

## Commands

```powershell
cd C:\Suresh\Agentic-SRE\terraform\terragrunt
terragrunt hcl fmt --check
cd .\environments\poc
terragrunt init
terragrunt validate
terragrunt plan
terragrunt output
```

`terragrunt run --all` is unnecessary for this single stack. Individual resource
unit folders are no longer deployment entry points. In VS Code, the **Terragrunt:
validate POC** task selects the combined POC stack.

Offline validation checks both environments without Azure or state access:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 `
  -TerragruntPath terragrunt -TerraformPath terraform -ValidateTerraform
```

The script uses temporary configurations and initializes with `-backend=false`.
Provider fixtures are retained on Windows because legacy PowerShell cannot clean
some long provider paths. Linux CI removes its temporary fixture normally.

## Pipeline and application delivery

[The pipeline runbook](../docs/pipelines.md) describes push/PR validation and
manual POC planning. The pipeline uses Terragrunt inputs, one combined backend,
and one saved plan. No apply job is enabled.

Function code and Foundry hosted-agent deployment remain separate workflows.
Configure mandatory Entra Easy Auth before Function deployment; registrations
alone do not configure API authentication. Create/select the Foundry project,
deploy `sre-alert-postgres-hosted`, and supply its endpoint. Configure the hosted
agent's `POSTGRES_HOST`, `POSTGRES_DATABASE`, and `POSTGRES_AAD_USER`, then bootstrap
its database role and grants following [the agent README](../applications/foundry-hosted-alert-agent/README.md).
Private networking and production firewall/identity review remain required.