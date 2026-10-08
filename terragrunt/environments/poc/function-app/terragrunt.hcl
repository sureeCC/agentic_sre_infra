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
  function_app_name = "func-agenticsre-poc-244b"
  service_plan_name = "WestUSPlan"
  service_plan_sku  = "Y1"
  os_type           = "Windows"
  # Match the adopted POC. Set true in both configurations after migration.
  https_only                               = false
  always_on                                = false
  ftps_state                               = "FtpsOnly"
  http2_enabled                            = false
  storage_account_name                     = "stfuncagentsre244b"
  storage_replication_type                 = "LRS"
  application_insights_name                = "func-agenticsre-poc-244b"
  application_insights_sampling_percentage = 0
  resource_group_name                      = dependency.resource_group.outputs.name
  location                                 = include.common.locals.location
  event_hub_id                             = dependency.event_hubs.outputs.event_hub_ids["testeventhub"]
  event_hubs_fully_qualified_namespace     = dependency.event_hubs.outputs.fully_qualified_namespace
  event_hub_name                           = "testeventhub"
  event_hub_consumer_group                 = "$Default"
  foundry_project_endpoint                 = "https://agenticsre.services.ai.azure.com/api/projects/proj-agenticsre"
  foundry_alert_agent_name                 = "sre-alert-postgres-hosted"
  foundry_resource_id                      = dependency.foundry.outputs.id
  assign_foundry_invoker_role              = false
  log_analytics_workspace_id               = include.common.locals.log_analytics_workspace_id
  additional_app_settings = {

  }
  tags = include.common.locals.tags
}
