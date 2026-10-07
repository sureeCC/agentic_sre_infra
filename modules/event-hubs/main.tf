resource "azurerm_eventhub_namespace" "this" {
  name                          = var.namespace_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  capacity                      = var.capacity
  auto_inflate_enabled          = var.auto_inflate_enabled
  maximum_throughput_units      = var.auto_inflate_enabled ? var.maximum_throughput_units : null
  local_authentication_enabled  = var.local_authentication_enabled
  public_network_access_enabled = var.public_network_access_enabled
  minimum_tls_version           = "1.2"
  tags                          = var.tags
}

resource "azurerm_eventhub" "this" {
  for_each = var.event_hubs

  name                = each.key
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = var.resource_group_name
  partition_count     = each.value.partition_count
  message_retention   = each.value.message_retention_days
}

locals {
  consumer_groups = merge([
    for event_hub_name, event_hub in var.event_hubs : {
      for consumer_group in event_hub.consumer_groups :
      "${event_hub_name}/${consumer_group}" => {
        event_hub_name = event_hub_name
        name           = consumer_group
      }
    }
  ]...)
}

resource "azurerm_eventhub_consumer_group" "this" {
  for_each = local.consumer_groups

  name                = each.value.name
  namespace_name      = azurerm_eventhub_namespace.this.name
  eventhub_name       = azurerm_eventhub.this[each.value.event_hub_name].name
  resource_group_name = var.resource_group_name
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.log_analytics_workspace_id == null ? 0 : 1

  name                       = "diag-${var.namespace_name}"
  target_resource_id         = azurerm_eventhub_namespace.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
