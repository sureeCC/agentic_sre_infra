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
dependency "identity" {
  config_path = "../managed-identity"
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
