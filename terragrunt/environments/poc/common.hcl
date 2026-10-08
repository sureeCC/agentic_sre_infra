# Shared environment identity, location, and tags.
locals {
  # Shared values override matching inputs in the combined stack.
  config = {
    "subscription_id"         = "244b1140-2e3c-4232-8c86-2b77c04ca37e"
    "tenant_id"               = "89c39546-9370-4770-a920-ea7f83a9c45e"
    "resource_group_name"     = "test"
    "location"                = "westus"
    "resource_group_location" = "eastus"
    "environment"             = "poc"
    "owner"                   = "platform-engineering"
    "cost_center"             = "sre-poc"
    "data_classification"     = "internal"
    "additional_tags" = {
      "application" = "agentic-sre"
      "lifecycle"   = "experimental"
    }
    "manage_tags"                = false
    "log_analytics_workspace_id" = null
  }
}
