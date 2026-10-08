include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//event-hubs${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
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
  namespace_name                = "pocagenticsre"
  location                      = include.common.locals.location
  resource_group_name           = dependency.resource_group.outputs.name
  sku                           = "Basic"
  capacity                      = 1
  auto_inflate_enabled          = false
  maximum_throughput_units      = 4
  local_authentication_enabled  = true
  public_network_access_enabled = true
  event_hubs = {
    "testeventhub" = {
      "consumer_groups"        = []
      "message_retention_days" = 1
      "partition_count"        = 1
    }
  }
  log_analytics_workspace_id = include.common.locals.log_analytics_workspace_id
  tags                       = include.common.locals.tags
}
