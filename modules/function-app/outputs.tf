output "id" {
  value = local.function_app_id
}
output "name" {
  value = local.function_app_name
}
output "default_hostname" {
  value = local.function_app_default_hostname
}
output "principal_id" {
  value = local.function_app_principal_id
}
output "application_insights_id" {
  value = azurerm_application_insights.this.id
}
