variable "subscription_id" {
  description = "Azure subscription ID. Supply through a secure tfvars file or CI/CD variable."
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID. Supply through a secure tfvars file or CI/CD variable."
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "poc", "stage", "prod"], lower(var.environment))
    error_message = "environment must be dev, test, poc, stage, or prod."
  }
}

variable "resource_group_name" {
  description = "Name of the Resource Group managed or imported by this environment."
  type        = string
}

variable "location" {
  description = "Azure region for workload resources."
  type        = string
  default     = "westus"
}

variable "resource_group_location" {
  description = "Azure region recorded on the Resource Group. This may differ from the regions of workload resources."
  type        = string
  default     = "westus"
}

variable "owner" {
  description = "Operational owner tag, for example an email alias or team name."
  type        = string
}

variable "cost_center" {
  description = "Cost centre tag used for chargeback/showback."
  type        = string
}

variable "data_classification" {
  description = "Highest intended data classification."
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], lower(var.data_classification))
    error_message = "data_classification must be public, internal, confidential, or restricted."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive tags for the Resource Group. Required tags cannot be omitted."
  type        = map(string)
  default     = {}
}

variable "manage_tags" {
  description = "Whether Terraform enforces required tags. Set false only while importing an untagged legacy POC."
  type        = bool
  default     = true
}

variable "event_hubs_namespace_name" {
  description = "Globally unique Azure Event Hubs namespace name."
  type        = string
}

variable "event_hubs_sku" {
  description = "Event Hubs SKU. Use Standard for the production baseline."
  type        = string
  default     = "Standard"
}

variable "event_hubs_capacity" {
  description = "Initial Event Hubs namespace capacity units."
  type        = number
  default     = 1
}

variable "event_hubs_auto_inflate_enabled" {
  description = "Whether Event Hubs Standard auto-inflate is enabled."
  type        = bool
  default     = false
}

variable "event_hubs_local_authentication_enabled" {
  description = "Whether Event Hubs local/SAS authentication is enabled."
  type        = bool
  default     = false
}

variable "event_hubs_maximum_throughput_units" {
  description = "Maximum units allowed by Event Hubs auto-inflate."
  type        = number
  default     = 4
}

variable "event_hubs_public_network_access_enabled" {
  description = "Keep true until private endpoint and private DNS are deployed."
  type        = bool
  default     = true
}

variable "event_hubs" {
  description = "Event Hubs and their explicit consumer groups."
  type = map(object({
    partition_count        = number
    message_retention_days = number
    consumer_groups        = set(string)
  }))
}

variable "log_analytics_workspace_id" {
  description = "Optional resource ID for a central Log Analytics workspace."
  type        = string
  default     = null
  nullable    = true
}

variable "function_app_name" {
  description = "Globally unique Function App name."
  type        = string
}

variable "function_service_plan_name" {
  description = "Name for the Function Premium service plan."
  type        = string
}

variable "function_service_plan_sku" {
  description = "Function hosting plan SKU, for example Y1 or EP1."
  type        = string
  default     = "EP1"
}

variable "function_os_type" {
  description = "Operating system for the Function App hosting plan."
  type        = string
  default     = "Linux"
}

variable "function_https_only" {
  description = "Whether the Function App enforces HTTPS-only traffic."
  type        = bool
  default     = true
}

variable "function_always_on" {
  description = "Enable Always On. Set false for Consumption Y1."
  type        = bool
  default     = true
}

variable "function_ftps_state" {
  description = "FTP/FTPS access mode for the Function App."
  type        = string
  default     = "Disabled"
}

variable "function_http2_enabled" {
  description = "Whether HTTP/2 is enabled for the Function App."
  type        = bool
  default     = true
}

variable "function_storage_account_name" {
  description = "Globally unique storage account name for Function host storage."
  type        = string
}

variable "function_storage_replication_type" {
  description = "Replication level for Function host storage."
  type        = string
  default     = "ZRS"
}

variable "application_insights_name" {
  description = "Application Insights name for Function telemetry."
  type        = string
}

variable "application_insights_sampling_percentage" {
  description = "Application Insights sampling percentage."
  type        = number
  default     = 100
}

variable "function_event_hub_name" {
  description = "Event Hub to which the Function is granted sender and receiver roles."
  type        = string
  default     = "testeventhub"
}

variable "function_event_hub_consumer_group" {
  description = "Dedicated consumer group used by the Function Event Hubs trigger."
  type        = string
  default     = "foundry-agent-dispatcher"
}

variable "foundry_project_endpoint" {
  description = "Foundry project endpoint used by the Function dispatcher."
  type        = string
}

variable "foundry_alert_agent_name" {
  description = "Foundry Hosted Agent name invoked by the Function dispatcher."
  type        = string
  default     = "sre-alert-postgres-hosted"
}

variable "foundry_resource_id" {
  description = "Optional Foundry/Azure AI resource ID for Cognitive Services OpenAI User assignment."
  type        = string
  default     = null
  nullable    = true
}

variable "function_assign_foundry_invoker_role" {
  description = "Whether Terraform manages the Function identity's Foundry invocation role assignment."
  type        = bool
  default     = true
}

variable "foundry_resource_name" {
  description = "Globally unique Azure AI Services resource name used by Microsoft Foundry."
  type        = string
}

variable "foundry_sku_name" {
  description = "Foundry Azure AI Services SKU."
  type        = string
  default     = "S0"
}

variable "foundry_local_auth_enabled" {
  description = "Whether local key authentication is enabled on the Foundry resource."
  type        = bool
  default     = false
}

variable "foundry_project_management_enabled" {
  description = "Whether Foundry project management is enabled."
  type        = bool
  default     = false
}

variable "foundry_custom_subdomain_name" {
  description = "Unique custom subdomain for the Foundry Azure AI Services resource."
  type        = string
}

variable "foundry_create_model_deployment" {
  description = "Create the model deployment. Keep false when importing or using the existing POC deployment."
  type        = bool
  default     = false
}

variable "foundry_model_deployment_name" {
  description = "Foundry model deployment name."
  type        = string
  default     = "alert-agent-mini"
}

variable "foundry_model_format" {
  description = "Foundry model format."
  type        = string
  default     = "OpenAI"
}

variable "foundry_model_name" {
  description = "Foundry model name available in the selected region."
  type        = string
  default     = "gpt-4.1-mini"
}

variable "foundry_model_version" {
  description = "Foundry model version available in the selected region."
  type        = string
  default     = "2025-04-14"
}

variable "foundry_model_sku_name" {
  description = "Foundry model deployment SKU."
  type        = string
  default     = "GlobalStandard"
}

variable "foundry_model_sku_capacity" {
  description = "Foundry model deployment capacity."
  type        = number
  default     = 1
}

variable "function_additional_app_settings" {
  description = "Extra non-secret Function application settings."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "function_api_display_name" {
  description = "Microsoft Entra app registration display name for the Function ingress API."
  type        = string
  default     = "agentic-sre-alert-api"
}

variable "function_api_identifier_uri" {
  description = "Microsoft Entra Application ID URI used as the Function API audience."
  type        = string
}

variable "kibana_client_display_name" {
  description = "Microsoft Entra app registration display name for Kibana."
  type        = string
  default     = "kibana-alerting-client"
}

variable "kibana_alert_send_role_id" {
  description = "Stable UUID assigned to the Kibana.Alert.Send app role."
  type        = string
}

variable "app_registration_access_token_version" { type = number }
variable "app_registration_kibana_role_description" { type = string }
variable "app_registration_kibana_role_display_name" { type = string }
variable "app_registration_manage_owners" { type = bool }
variable "app_registration_enterprise_feature_tag_enabled" { type = bool }
variable "app_registration_function_api_assignment_required" { type = bool }
variable "app_registration_manage_kibana_required_resource_access" { type = bool }

variable "postgresql_server_name" {
  description = "Globally unique PostgreSQL Flexible Server name."
  type        = string
}

variable "postgresql_tags" {
  description = "Tags to manage on PostgreSQL. Defaults to the environment tag policy when null."
  type        = map(string)
  default     = null
  nullable    = true
}

variable "postgresql_sku_name" {
  description = "PostgreSQL Flexible Server compute SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "postgresql_storage_mb" {
  description = "PostgreSQL storage allocation in MB."
  type        = number
  default     = 32768
}

variable "postgresql_backup_retention_days" {
  description = "PostgreSQL point-in-time restore retention in days."
  type        = number
  default     = 7
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Enable PostgreSQL geo-redundant backup."
  type        = bool
  default     = false
}

variable "postgresql_high_availability_enabled" {
  description = "Enable PostgreSQL zone-redundant high availability."
  type        = bool
  default     = false
}

variable "postgresql_zone" {
  description = "Optional PostgreSQL primary availability zone."
  type        = string
  default     = null
  nullable    = true
}

variable "postgresql_standby_availability_zone" {
  description = "Optional PostgreSQL standby availability zone."
  type        = string
  default     = null
  nullable    = true
}

variable "postgresql_public_network_access_enabled" {
  description = "Allow PostgreSQL public networking until a private endpoint is deployed."
  type        = bool
  default     = true
}

variable "postgresql_firewall_rules" {
  description = "Named PostgreSQL firewall rules for temporary public access."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}
}

variable "postgresql_database_name" {
  description = "PostgreSQL application database name."
  type        = string
  default     = "agenticsre"
}

variable "postgresql_entra_administrator_object_id" {
  description = "Object ID of the designated PostgreSQL Entra administrator, preferably a group."
  type        = string
}

variable "postgresql_entra_administrator_principal_name" {
  description = "Display name of the PostgreSQL Entra administrator principal."
  type        = string
}

variable "postgresql_entra_administrator_principal_type" {
  description = "Type of PostgreSQL Entra administrator principal."
  type        = string
  default     = "Group"
}
