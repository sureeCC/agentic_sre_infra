variable "namespace_name" {
  description = "Globally unique Event Hubs namespace name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{6,50}$", var.namespace_name))
    error_message = "namespace_name must contain 6-50 lowercase letters, numbers, or hyphens."
  }
}

variable "location" {
  description = "Azure region for the Event Hubs namespace."
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group that contains the Event Hubs namespace."
  type        = string
}

variable "sku" {
  description = "Event Hubs SKU. Standard is the production baseline for this workload."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard, or Premium."
  }
}

variable "capacity" {
  description = "Namespace capacity units."
  type        = number
  default     = 1

  validation {
    condition     = var.capacity >= 1
    error_message = "capacity must be at least 1."
  }
}

variable "auto_inflate_enabled" {
  description = "Enable Standard namespace auto-inflate for burst protection."
  type        = bool
  default     = false
}

variable "maximum_throughput_units" {
  description = "Maximum throughput units allowed when auto-inflate is enabled."
  type        = number
  default     = 4

  validation {
    condition     = var.maximum_throughput_units >= 1
    error_message = "maximum_throughput_units must be at least 1."
  }
}

variable "local_authentication_enabled" {
  description = "Allow SAS/local authentication. Keep false when all clients use Microsoft Entra ID and managed identities."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access. Set false only after private endpoints and private DNS are deployed."
  type        = bool
  default     = true
}

variable "event_hubs" {
  description = "Event Hubs and dedicated consumer groups to create."
  type = map(object({
    partition_count        = number
    message_retention_days = number
    consumer_groups        = set(string)
  }))

  validation {
    condition = alltrue([
      for name, hub in var.event_hubs :
      can(regex("^[a-z0-9-]{1,50}$", name)) &&
      hub.partition_count >= 1 &&
      hub.message_retention_days >= 1 &&
      !contains(hub.consumer_groups, "$Default")
    ])
    error_message = "Each hub needs a lowercase name, at least one partition and retention day, and an explicitly named consumer group (not $Default)."
  }
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics workspace resource ID for namespace diagnostics."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to the Event Hubs namespace."
  type        = map(string)
}
