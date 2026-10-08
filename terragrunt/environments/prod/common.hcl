# Central environment settings, tags, and module source selection.
locals {
  # Shared environment values; resource-specific inputs live in each unit.
  config = {
    "subscription_id"         = get_env("TG_PROD_SUBSCRIPTION_ID")
    "tenant_id"               = get_env("TG_PROD_TENANT_ID")
    "resource_group_name"     = "rg-agenticsre-prod-example"
    "location"                = "westus"
    "resource_group_location" = "westus"
    "environment"             = "prod"
    "owner"                   = "platform-engineering"
    "cost_center"             = get_env("TG_PROD_COST_CENTER")
    "data_classification"     = "internal"
    "additional_tags" = {

    }
    "manage_tags"                = true
    "log_analytics_workspace_id" = null
  }
  subscription_id            = local.config.subscription_id
  tenant_id                  = local.config.tenant_id
  resource_group_name        = local.config.resource_group_name
  location                   = local.config.location
  resource_group_location    = local.config.resource_group_location
  owner                      = local.config.owner
  cost_center                = local.config.cost_center
  data_classification        = local.config.data_classification
  additional_tags            = local.config.additional_tags
  manage_tags                = local.config.manage_tags
  log_analytics_workspace_id = local.config.log_analytics_workspace_id

  environment = local.config.environment
  # Existing modules are local. For centrally versioned modules set a Git URL
  # in iac_modules_repo and a reviewed tag/commit in module_ref.
  iac_modules_repo = "${dirname(find_in_parent_folders("root.hcl"))}/../modules"
  module_ref       = ""
  tags = local.config.manage_tags ? merge({
    environment         = local.environment
    workload            = "agentic-sre"
    owner               = local.config.owner
    cost_center         = local.config.cost_center
    data_classification = local.config.data_classification
    managed_by          = "terraform"
  }, local.config.additional_tags) : {}
}
