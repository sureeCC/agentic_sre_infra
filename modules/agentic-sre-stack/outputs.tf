output "resource_group_id" {
  description = "Resource ID of the managed Resource Group."
  value       = module.resource_group.id
}

output "resource_group_name" {
  description = "Name of the managed Resource Group."
  value       = module.resource_group.name
}

output "event_hubs_namespace" {
  description = "Fully qualified Event Hubs namespace for managed-identity clients."
  value       = module.event_hubs.fully_qualified_namespace
}

output "event_hub_ids" {
  description = "Event Hub resource IDs keyed by hub name."
  value       = module.event_hubs.event_hub_ids
}

output "function_app_hostname" {
  description = "Function App hostname. Entra ingress authentication is added in the Key Vault and Entra layer."
  value       = module.function_app.default_hostname
}

output "function_app_principal_id" {
  description = "Function App system-assigned managed identity principal ID."
  value       = module.function_app.principal_id
}

output "function_api_identifier_uri" {
  description = "Function API audience configured in App Service Authentication."
  value       = module.app_registrations.function_api_identifier_uri
}

output "kibana_oauth_client_id" {
  description = "Kibana OAuth client ID for the Webhook connector."
  value       = module.app_registrations.kibana_client_id
}

output "kibana_oauth_scope" {
  description = "OAuth scope configured in the Kibana Webhook connector."
  value       = module.app_registrations.oauth_scope
}

output "foundry_resource_id" {
  description = "Azure AI Services / Foundry resource ID."
  value       = module.foundry.id
}

output "foundry_endpoint" {
  description = "Foundry Azure AI Services endpoint."
  value       = module.foundry.endpoint
}

output "postgresql_fqdn" {
  description = "PostgreSQL Flexible Server hostname."
  value       = module.postgresql.fqdn
}

output "postgresql_database_name" {
  description = "PostgreSQL application database name."
  value       = module.postgresql.database_name
}
