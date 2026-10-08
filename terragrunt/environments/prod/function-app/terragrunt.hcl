include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//function-app${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
}

dependency "event_hubs" {
  skip_outputs                            = get_terraform_command() == "validate"
  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    event_hub_ids = {
      testeventhub = "/subscriptions/${include.common.locals.subscription_id}/resourceGroups/${include.common.locals.resource_group_name}/providers/Microsoft.EventHub/namespaces/validation/eventhubs/testeventhub"
      alerts       = "/subscriptions/${include.common.locals.subscription_id}/resourceGroups/${include.common.locals.resource_group_name}/providers/Microsoft.EventHub/namespaces/validation/eventhubs/alerts"
    }
    fully_qualified_namespace = "validation.servicebus.windows.net"
  }
  config_path = "../event-hubs"
}

dependency "foundry" {
  skip_outputs                            = get_terraform_command() == "validate"
  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    id = "/subscriptions/${include.common.locals.subscription_id}/resourceGroups/${include.common.locals.resource_group_name}/providers/Microsoft.CognitiveServices/accounts/validation"
  }
  config_path = "../foundry"
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
  function_app_name                        = "func-agenticsre-prod-example"
  service_plan_name                        = "plan-agenticsre-prod-example"
  service_plan_sku                         = "EP1"
  os_type                                  = "Linux"
  https_only                               = true
  always_on                                = true
  ftps_state                               = "Disabled"
  http2_enabled                            = true
  storage_account_name                     = "stagentprodexample"
  storage_replication_type                 = "ZRS"
  application_insights_name                = "appi-agenticsre-prod-example"
  application_insights_sampling_percentage = 100
  resource_group_name                      = dependency.resource_group.outputs.name
  location                                 = include.common.locals.location
  event_hub_id                             = dependency.event_hubs.outputs.event_hub_ids["alerts"]
  event_hubs_fully_qualified_namespace     = dependency.event_hubs.outputs.fully_qualified_namespace
  event_hub_name                           = "alerts"
  event_hub_consumer_group                 = "foundry-agent-dispatcher"
  foundry_project_endpoint                 = get_env("TG_PROD_FOUNDRY_PROJECT_ENDPOINT")
  foundry_alert_agent_name                 = "sre-alert-postgres-hosted"
  foundry_resource_id                      = dependency.foundry.outputs.id
  assign_foundry_invoker_role              = true
  log_analytics_workspace_id               = include.common.locals.log_analytics_workspace_id
  additional_app_settings = {

  }
  tags = include.common.locals.tags
}
