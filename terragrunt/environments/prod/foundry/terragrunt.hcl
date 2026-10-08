include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//foundry${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
}

dependency "resource_group" {
  # Validation checks schemas without requiring migrated upstream state.
  skip_outputs                            = get_terraform_command() == "validate"
  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    name = include.common.locals.resource_group_name
  }
  config_path = "../resource-group"
}

inputs = {
  name                       = "ai-agenticsre-prod-example"
  location                   = include.common.locals.location
  resource_group_name        = dependency.resource_group.outputs.name
  sku_name                   = "S0"
  local_auth_enabled         = false
  project_management_enabled = false
  custom_subdomain_name      = "ai-agenticsre-prod-example"
  create_model_deployment    = false
  model_deployment_name      = "alert-agent-mini"
  model_format               = "OpenAI"
  model_name                 = "gpt-4.1-mini"
  model_version              = "2025-04-14"
  model_sku_name             = "GlobalStandard"
  model_sku_capacity         = 1
  tags                       = include.common.locals.tags
}
