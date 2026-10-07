variable "function_app_name" { type = string }
variable "service_plan_name" { type = string }
variable "service_plan_sku" {
  type    = string
  default = "EP1"
  validation {
    condition     = can(regex("^(Y1|EP[1-3])$", var.service_plan_sku))
    error_message = "service_plan_sku must be a supported Functions SKU: Y1, EP1, EP2, or EP3."
  }
}
variable "os_type" {
  description = "Operating system of the Function App and App Service plan."
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be Linux or Windows."
  }
}

variable "https_only" {
  description = "Whether the Function App enforces HTTPS-only traffic."
  type        = bool
  default     = true
}

variable "always_on" {
  description = "Enable Always On. Consumption Y1 Function Apps must use false."
  type        = bool
  default     = true
}

variable "ftps_state" {
  description = "FTP/FTPS access mode for the Function App."
  type        = string
  default     = "Disabled"
}

variable "http2_enabled" {
  description = "Enable HTTP/2 for the Function App."
  type        = bool
  default     = true
}
variable "storage_account_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must contain 3-24 lowercase letters or numbers."
  }
}
variable "storage_replication_type" {
  type    = string
  default = "ZRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.storage_replication_type)
    error_message = "storage_replication_type must be a valid Azure Storage replication type."
  }
}
variable "application_insights_name" { type = string }
variable "application_insights_sampling_percentage" {
  description = "Application Insights sampling percentage."
  type        = number
  default     = 100
}
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "event_hub_id" { type = string }
variable "event_hubs_fully_qualified_namespace" { type = string }
variable "event_hub_name" { type = string }
variable "event_hub_consumer_group" { type = string }
variable "foundry_project_endpoint" { type = string }
variable "foundry_alert_agent_name" { type = string }
variable "foundry_resource_id" {
  type     = string
  default  = null
  nullable = true
}
variable "assign_foundry_invoker_role" {
  description = "Create the Cognitive Services OpenAI User role assignment for the Function identity."
  type        = bool
  default     = true
}
variable "log_analytics_workspace_id" {
  type     = string
  default  = null
  nullable = true
}
variable "additional_app_settings" {
  type      = map(string)
  default   = {}
  sensitive = true
}
variable "tags" { type = map(string) }
