# Shared environment identity, location, and tags.
locals {
  # Shared values override matching inputs in the combined stack.
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
}
