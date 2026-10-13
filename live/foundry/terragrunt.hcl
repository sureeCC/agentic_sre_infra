include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Foundry/AI-Foundry" : "${include.common.locals.iac_modules_repo}//Foundry/AI-Foundry?ref=${include.common.locals.module_ref}"
}
generate "foundry_provider_override" {
  path      = "zz_foundry_provider_override.tf"
  if_exists = "overwrite_terragrunt"
  # Terraform merges this override into the module's existing provider block.
  # Keep the RG-scoped pipeline identity; normal destroy leaves a recoverable account.
  contents = <<-EOF
provider "azurerm" {
  features {
    cognitive_account {
      purge_soft_delete_on_destroy = false
    }
  }
}
EOF
}
dependency "identity" {
  config_path = "../managed-identity"
  # Bootstrap plans can preview Foundry before the identity has state outputs.
  # This is its deterministic future ID, not proof the identity exists.
  mock_outputs = {
    managed_identity_id = "/subscriptions/${include.common.inputs.subscription_id}/resourceGroups/${include.common.inputs.resource_group_name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${include.common.locals.names.identity_prefix}-${include.common.locals.name_suffix}"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}
inputs = {
  resource_prefix               = "ai-sre"
  foundry_name                  = include.common.locals.names.foundry
  sku_name                      = "S0"
  project_management_enabled    = true
  local_authentication_enabled  = false
  identity_type                 = "UserAssigned"
  identity_ids                  = [dependency.identity.outputs.managed_identity_id]
  public_network_access_enabled = false
  vnet_name                     = include.common.locals.environment.vnet_name
  vnet_resource_group_name      = include.common.locals.environment.vnet_resource_group_name
  subnet_name                   = include.common.locals.environment.pve_subnet_name
  projects = {
    imo = {
      name          = include.common.locals.names.foundry_project
      display_name  = "Agentic SRE IMO"
      identity_type = "SystemAssigned"
    }
  }
  deployments = {
    alert-agent-mini = {
      model_format  = "OpenAI"
      model_name    = include.common.locals.environment.model_name
      model_version = include.common.locals.environment.model_version
      sku_name      = "GlobalStandard"
      sku_capacity  = include.common.locals.environment.model_capacity
    }
  }
}
