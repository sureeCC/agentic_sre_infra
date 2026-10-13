# Infrastructure deployment setup

Deployment units are in live/. Reusable Terraform modules are in the private sureeCC/agentic_sre_modules repository, pinned by the MODULE_REF commit SHA. Prior application code and legacy Terraform directories are retained; the old combined-state terraform.yml workflow is archived under docs/legacy-workflows and no longer runs.

Run the Agentic SRE infrastructure workflow from main. Choose dev/qa/prod, one unit, and plan/apply. Apply plans and applies in one job. Configure Environment protection rules before allowing production apply. The workflow refuses subscriptions/tenants other than the authorized personal Azure account.

Create a private blob container named tfstate in each state storage account. A separate lock resource is not needed: the Azure backend uses blob leases. Each unit/environment has its own state key: agentic_sre_infra/<unit>/<environment>/terraform.tfstate. Backends must exist before the pipeline runs. Do not reuse combined legacy state without an explicit state migration.

## GitHub Environment settings

Create dev and prod (or qa if those are your two environments). Each Environment needs variables:

AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
LOCATION, REGION, INSTANCE, RESOURCE_GROUP_NAME,
VNET_NAME, VNET_RESOURCE_GROUP_NAME, PVE_SUBNET_NAME, SVC_SUBNET_NAME,
POSTGRES_DNS_ZONE_NAME, POSTGRES_DNS_RESOURCE_GROUP,
MODEL_NAME, MODEL_VERSION, MODEL_CAPACITY (Foundry only; capacity defaults to 1),
APP, OWNER, PROVISIONED_TIME,
STATE_RESOURCE_GROUP, STATE_STORAGE_ACCOUNT, STATE_CONTAINER.

MODULE_REF is configured as a repository variable to the module commit; environment overrides are optional. IAC_MODULES_REPO is optional because project.hcl defaults to the new module repository. LOCATION is the Azure location, REGION is a short naming code (eus), INSTANCE is typically 001. PROVISIONED_TIME must be fixed RFC3339 metadata, not a changing timestamp.

Secrets: MODULES_READ_TOKEN (fine-grained token with Contents: read for the private modules repository), POSTGRES_ADMIN_PASSWORD for database. Do not paste or commit secrets. No Azure client secret is needed with OIDC.

Configure Azure OIDC federation for this GitHub repository and each Environment. Check the repository's actual OIDC subject format when creating federation; GitHub subject defaults can vary. Give the deployment identity Contributor on the workload RG and Storage Blob Data Contributor on the state container/account. Additional role-assignment permissions are needed if you later add RBAC resources.

The current Azure modules require existing networking and private DNS/RBAC. The GitHub-hosted runner must reach any private data endpoints used by a resource; a connected self-hosted runner may be needed. Deploy managed-identity before foundry. ACR is Premium to support its private endpoint. Backend storage and workload/network settings have not been populated because their names are not yet supplied.

Module initialization/validation passed locally before publication. Outstanding runtime findings remain in the modules repository docs/MODULE-REVIEW.md. This is a pipeline scaffold, not a completed application deployment. No workflow has been dispatched to Azure.

## Local use

Set LOCAL_MODULES_ROOT to a clone of agentic_sre_modules, with forward slashes. Export the same configuration variables plus BRANCH_NAME and GITHUB_REPOSITORY. Run Terragrunt inside live/<unit>. Keep real remote state for meaningful plans.

## Automatic naming

Shared/naming still owns managed identity, Key Vault and PostgreSQL names. Terragrunt derives required explicit ACR/Foundry/Event Hub names in live/common.hcl using the same prefix-environment-region-instance ordering. Globally unique explicit account names include the first six subscription hex characters. ACR removes separators. Key Vault uses a compact prefix and four-character subscription suffix to stay within 24 characters. Uniqueness is not guaranteed by a suffix; Azure checks availability at creation.

Default Dev names with APP=agenticsre, REGION=wus, INSTANCE=001:
- Managed identity: mi-agenticsre-dev-wus-001
- Key Vault: kv-sre-244b-dev-wus-001
- PostgreSQL: pg-sre-244b11-dev-wus-001
- ACR: acragenticsredevwus001244b11
- Foundry: ai-agenticsre-dev-wus-001-244b11
- Foundry project: proj-agenticsre-dev-wus-001
- Event Hub namespace: ehns-agenticsre-dev-wus-001-244b11

QA substitutes qa for dev. ACR_NAME, FOUNDRY_NAME, FOUNDRY_PROJECT_NAME and EVENTHUB_NAMESPACE_NAME are no longer required GitHub variables. Backend/network names reference resources already provisioned and remain configured. Database DNS settings/password are checked only for database; model settings only for foundry. All units share configuration parsing, with unrelated model/DNS values allowed to be empty.

These naming changes apply to new resources. Review plans carefully before changing names of resources already managed in state: renames can force replacement. Precreated pipeline identities, VNets and state storage retain their existing names.

## All resource units

Choose Unit=all to run managed-identity, event-hub, acr, key-vault, database and foundry. Each keeps its existing per-unit/environment state blob. Separate pipeline steps validate all selected units, plan all selected units, and then apply the exact saved plans when Action=apply. A failed validation or plan prevents every apply. Execution failures stop later units; earlier successful applies remain deployed.

All requires the database DNS/password and Foundry model configuration in addition to shared settings. Environment-level concurrency prevents all and single-unit runs overlapping. Per-unit results appear in the run summary and grouped logs.

For first-time plans, Foundry may use a deterministic preview identity ID when no managed-identity outputs exist. Mock outputs are allowed only for init/validate/plan, never apply. Managed identity is applied first; its real state outputs are available when Foundry's saved plan is applied.

Action=destroy validates and creates saved destruction plans, then executes them in reverse dependency order: foundry, database, key-vault, acr, event-hub, managed-identity. It deletes only resources managed by the selected units' state, not the separately provisioned VNets, state storage or pipeline identities. Destroy does not bypass Azure deletion protection or locks.

Foundry's Terragrunt unit generates `zz_foundry_provider_override.tf` to set AzureRM `cognitive_account.purge_soft_delete_on_destroy=false`. Normal destroy soft-deletes the account without requesting permanent purge permissions outside the pipeline identity's resource-group scope. The module's provider version and subscription configuration stay in place. Reusing the same account name may require recovery or a separately authorized purge. Start a fresh workflow after partial failures so plans refresh the remaining state.

Key Vault similarly generates `zz_keyvault_provider_override.tf` with `key_vault.purge_soft_delete_on_destroy=false`. This skips AzureRM's subscription-scoped deleted-vault lookup after deletion, while preserving purge protection and the seven-day soft-delete retention. No extra identity permissions are required for that lookup. A deleted vault name remains reserved during retention; recover the vault or wait for retention expiry before reusing it.

The run summary retains unit success/failure results and adds a table of Terraform resource addresses. Plans distinguish new resources, unchanged existing resources, updates, replacements and deletions. Successful executions report created, already existing, updated, replaced or deleted resources. Failed executions mark outcomes unconfirmed because a partial apply can succeed before an error. "Not in state" does not prove a same-named unmanaged Azure resource is absent; such resources require import. Saved plans remain on the runner; summaries contain only resource addresses and actions, never plan values or passwords.
