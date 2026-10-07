variable "function_api_display_name" {
  description = "Display name for the Function ingress API app registration."
  type        = string
}

variable "function_api_identifier_uri" {
  description = "Unique Application ID URI, for example api://agenticsre-alert-api-prod."
  type        = string

  validation {
    condition     = startswith(var.function_api_identifier_uri, "api://")
    error_message = "function_api_identifier_uri must start with api://."
  }
}

variable "kibana_client_display_name" {
  description = "Display name for the Kibana confidential-client app registration."
  type        = string
}

variable "kibana_alert_send_role_id" {
  description = "Stable UUID used for the Kibana.Alert.Send app role. Generate once and never change after deployment."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.kibana_alert_send_role_id))
    error_message = "kibana_alert_send_role_id must be a UUID."
  }
}

variable "access_token_version" {
  description = "Requested access-token version for the ingress API. Use 1 only when adopting a legacy POC API."
  type        = number
  default     = 2
}

variable "kibana_alert_send_role_description" {
  description = "Description of the Kibana Alert Send application role."
  type        = string
  default     = "Allows a trusted Kibana service principal to submit an alert event."
}

variable "kibana_alert_send_role_display_name" {
  description = "Display name of the Kibana Alert Send application role."
  type        = string
  default     = "Kibana Alert Send"
}

variable "manage_owners" {
  description = "Whether Terraform manages Entra application and service-principal owners."
  type        = bool
  default     = true
}

variable "enterprise_feature_tag_enabled" {
  description = "Whether to enable the Entra enterprise feature tag on the application registrations."
  type        = bool
  default     = true
}

variable "function_api_app_role_assignment_required" {
  description = "Whether users and applications must be assigned an app role before accessing the API enterprise application."
  type        = bool
  default     = true
}

variable "manage_kibana_required_resource_access" {
  description = "Whether Terraform manages the Kibana client's required-resource-access declaration."
  type        = bool
  default     = true
}
