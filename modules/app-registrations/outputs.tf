output "function_api_client_id" {
  description = "Client ID of the Function API app registration."
  value       = azuread_application.function_api.client_id
}

output "function_api_identifier_uri" {
  description = "Application ID URI used as the OAuth audience and scope prefix."
  value       = var.function_api_identifier_uri
}

output "function_api_service_principal_object_id" {
  description = "Enterprise application object ID for the Function API."
  value       = azuread_service_principal.function_api.object_id
}

output "kibana_client_id" {
  description = "Client ID configured in the Kibana Webhook connector."
  value       = azuread_application.kibana_client.client_id
}

output "kibana_client_service_principal_object_id" {
  description = "Enterprise application object ID for the Kibana confidential client."
  value       = azuread_service_principal.kibana_client.object_id
}

output "oauth_scope" {
  description = "Scope value configured in Kibana for client-credentials token acquisition."
  value       = "${var.function_api_identifier_uri}/.default"
}
