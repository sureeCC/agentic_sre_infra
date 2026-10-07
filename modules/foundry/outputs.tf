output "id" {
  description = "Azure AI Services / Foundry resource ID."
  value       = azurerm_cognitive_account.this.id
}

output "endpoint" {
  description = "Azure AI Services endpoint."
  value       = azurerm_cognitive_account.this.endpoint
}

output "principal_id" {
  description = "System-assigned identity principal ID of the Foundry resource."
  value       = azurerm_cognitive_account.this.identity[0].principal_id
}

output "model_deployment_id" {
  description = "Model deployment resource ID when one is created."
  value       = try(azurerm_cognitive_deployment.alert_model[0].id, null)
}
