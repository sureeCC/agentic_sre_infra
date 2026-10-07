resource "azurerm_cognitive_account" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  kind                       = "AIServices"
  sku_name                   = var.sku_name
  custom_subdomain_name      = var.custom_subdomain_name
  local_auth_enabled         = var.local_auth_enabled
  project_management_enabled = var.project_management_enabled

  network_acls {
    default_action = "Allow"
    ip_rules       = []
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "alert_model" {
  count = var.create_model_deployment ? 1 : 0

  name                 = var.model_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = var.model_format
    name    = var.model_name
    version = var.model_version
  }

  sku {
    name     = var.model_sku_name
    capacity = var.model_sku_capacity
  }
}
