output "namespace_id" {
  description = "Resource ID of the Event Hubs namespace."
  value       = azurerm_eventhub_namespace.this.id
}

output "namespace_name" {
  description = "Name of the Event Hubs namespace."
  value       = azurerm_eventhub_namespace.this.name
}

output "fully_qualified_namespace" {
  description = "Fully qualified namespace for managed-identity Event Hubs clients."
  value       = "${azurerm_eventhub_namespace.this.name}.servicebus.windows.net"
}

output "event_hub_ids" {
  description = "Resource IDs keyed by Event Hub name."
  value       = { for name, event_hub in azurerm_eventhub.this : name => event_hub.id }
}
