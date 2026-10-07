output "id" {
  description = "Resource ID of the Resource Group."
  value       = azurerm_resource_group.this.id
}

output "name" {
  description = "Name of the Resource Group."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Azure region of the Resource Group."
  value       = azurerm_resource_group.this.location
}
