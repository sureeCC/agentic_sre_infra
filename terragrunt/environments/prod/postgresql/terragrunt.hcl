include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//postgresql${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
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
  server_name                   = "pg-agenticsre-prod-example"
  resource_group_name           = dependency.resource_group.outputs.name
  location                      = include.common.locals.location
  tenant_id                     = include.common.locals.tenant_id
  sku_name                      = "GP_Standard_D2s_v3"
  postgresql_version            = "16"
  storage_mb                    = 32768
  backup_retention_days         = 35
  geo_redundant_backup_enabled  = false
  high_availability_enabled     = true
  zone                          = "1"
  standby_availability_zone     = "2"
  public_network_access_enabled = true
  # Supply reviewed client egress IP ranges; no broad Azure-services rule.
  firewall_rules                     = jsondecode(get_env("TG_PROD_POSTGRES_FIREWALL_RULES"))
  database_name                      = "agenticsre"
  entra_administrator_object_id      = get_env("TG_PROD_POSTGRES_ADMIN_OBJECT_ID")
  entra_administrator_principal_name = "agenticsre-prod-db-admins"
  entra_administrator_principal_type = "Group"
  log_analytics_workspace_id         = include.common.locals.log_analytics_workspace_id
  tags                               = include.common.locals.tags
}
