# Versioned POC configuration. Keep credentials and secrets out of this file.
subscription_id         = "244b1140-2e3c-4232-8c86-2b77c04ca37e"
tenant_id               = "89c39546-9370-4770-a920-ea7f83a9c45e"
resource_group_name     = "test"
location                = "westus"
resource_group_location = "eastus"
environment             = "poc"
owner                   = "platform-engineering"
cost_center             = "sre-poc"
data_classification     = "internal"

additional_tags = {
  application = "agentic-sre"
  lifecycle   = "experimental"
}

# Existing POC resources are untagged. Keep the production default (true) in
# other environments so Terraform enforces the required governance tags.
manage_tags = false

# Use a globally unique namespace name. Existing POC resources must be imported,
# not recreated. The POC currently uses pocagenticsre / testeventhub.
event_hubs_namespace_name                = "pocagenticsre"
event_hubs_sku                           = "Basic"
event_hubs_capacity                      = 1
event_hubs_auto_inflate_enabled          = false
event_hubs_maximum_throughput_units      = 4
event_hubs_local_authentication_enabled  = true
event_hubs_public_network_access_enabled = true

event_hubs = {
  "testeventhub" = {
    partition_count        = 1
    message_retention_days = 1
    # The existing hub has only Azure's built-in $Default group.
    consumer_groups = []
  }
}

# Function hosting and managed-identity dispatch. Function code is deployed by
# CI/CD after infrastructure review and apply.
function_app_name                        = "func-agenticsre-poc-244b"
function_service_plan_name               = "WestUSPlan"
function_service_plan_sku                = "Y1"
function_os_type                         = "Windows"
function_storage_account_name            = "stfuncagentsre244b"
function_storage_replication_type        = "LRS"
application_insights_name                = "func-agenticsre-poc-244b"
application_insights_sampling_percentage = 0
function_https_only                      = false
function_always_on                       = false
function_ftps_state                      = "FtpsOnly"
function_http2_enabled                   = false
function_event_hub_name                  = "testeventhub"
function_event_hub_consumer_group        = "$Default"

# These values are non-secret. The Foundry resource ID is added after the
# Foundry layer is imported or provisioned.
foundry_project_endpoint = "https://agenticsre.services.ai.azure.com/api/projects/proj-agenticsre"
foundry_alert_agent_name = "sre-alert-postgres-hosted"
# This is disabled while importing the existing role assignments separately.
function_assign_foundry_invoker_role = false

# Foundry resource and model deployment. Start with create_model_deployment =
# false when taking ownership of the existing POC; import it before enabling a
# plan. Confirm model availability and quota in the target region first.
foundry_resource_name              = "agenticsre"
foundry_custom_subdomain_name      = "agenticsre"
foundry_sku_name                   = "S0"
foundry_local_auth_enabled         = true
foundry_project_management_enabled = true
foundry_create_model_deployment    = false
foundry_model_deployment_name      = "alert-agent-mini"
foundry_model_format               = "OpenAI"
foundry_model_name                 = "gpt-4.1-mini"
foundry_model_version              = "2025-04-14"
foundry_model_sku_name             = "GlobalStandard"
foundry_model_sku_capacity         = 1

# Microsoft Entra application registrations. Generate the UUID once with
# `New-Guid`, then retain it forever to avoid changing a deployed app-role ID.
function_api_display_name   = "agenticsre-kibana-ingress-api"
function_api_identifier_uri = "api://052b5b68-f1aa-4a9f-b975-8e743f359565"
kibana_client_display_name  = "agenticsre-kibana-webhook-client"
kibana_alert_send_role_id   = "4c9cd731-8f05-4f18-89ca-42c62c0f4150"

# Existing portal-created Entra configuration adopted by this POC.
app_registration_access_token_version                   = 1
app_registration_kibana_role_description                = "Allows Kibana to send alert events to the ingress API."
app_registration_kibana_role_display_name               = "Kibana.Alert.Send"
app_registration_manage_owners                          = false
app_registration_enterprise_feature_tag_enabled         = false
app_registration_function_api_assignment_required       = false
app_registration_manage_kibana_required_resource_access = false

# PostgreSQL uses Microsoft Entra-only authentication. No administrator password
# is configured or stored. Use a security group as the Entra administrator.
postgresql_server_name                   = "pg-agenticsre-poc-244b"
postgresql_sku_name                      = "B_Standard_B1ms"
postgresql_version                       = "16"
postgresql_storage_mb                    = 32768
postgresql_backup_retention_days         = 7
postgresql_geo_redundant_backup_enabled  = false
postgresql_high_availability_enabled     = false
postgresql_public_network_access_enabled = true
postgresql_database_name                 = "agenticsre"
postgresql_tags = {
  CostProfile = "minimum"
  Environment = "POC"
  Workload    = "agentic-sre"
}
postgresql_entra_administrator_object_id      = "e1db7ae1-32c8-47da-b760-749afb295698"
postgresql_entra_administrator_principal_name = "suresh selvam"
postgresql_entra_administrator_principal_type = "User"

# Remove public rules and set public_network_access_enabled = false after
# private endpoint and private DNS Terraform modules are added.
postgresql_firewall_rules = {
  "allow-azure-services-poc" = {
    start_ip_address = "0.0.0.0"
    end_ip_address   = "0.0.0.0"
  }
  "codex-bootstrap-workstation"      = { start_ip_address = "182.156.9.21", end_ip_address = "182.156.9.21" }
  "function-outbound-104-45-212-38"  = { start_ip_address = "104.45.212.38", end_ip_address = "104.45.212.38" }
  "function-outbound-104-45-214-17"  = { start_ip_address = "104.45.214.17", end_ip_address = "104.45.214.17" }
  "function-outbound-104-45-215-181" = { start_ip_address = "104.45.215.181", end_ip_address = "104.45.215.181" }
  "function-outbound-104-45-215-185" = { start_ip_address = "104.45.215.185", end_ip_address = "104.45.215.185" }
  "function-outbound-104-45-216-224" = { start_ip_address = "104.45.216.224", end_ip_address = "104.45.216.224" }
  "function-outbound-104-45-222-185" = { start_ip_address = "104.45.222.185", end_ip_address = "104.45.222.185" }
  "function-outbound-40-112-243-96"  = { start_ip_address = "40.112.243.96", end_ip_address = "40.112.243.96" }
  "laptop-vscode"                    = { start_ip_address = "27.5.183.121", end_ip_address = "27.5.183.121" }
}

# Set after a central Log Analytics workspace is provisioned.
# log_analytics_workspace_id = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<name>"
