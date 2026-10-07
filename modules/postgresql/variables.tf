variable "server_name" {
  description = "Globally unique PostgreSQL Flexible Server name."
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group for PostgreSQL."
  type        = string
}

variable "location" {
  description = "Azure region for PostgreSQL."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID used for Entra-only database authentication."
  type        = string
}

variable "sku_name" {
  description = "PostgreSQL Flexible Server compute SKU. Use General Purpose for production HA workloads."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "storage_mb" {
  description = "Allocated database storage in MB."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Point-in-time restore retention in days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups where the selected region and SKU support them."
  type        = bool
  default     = false
}

variable "high_availability_enabled" {
  description = "Enable zone-redundant high availability for production workloads."
  type        = bool
  default     = false
}

variable "zone" {
  description = "Optional primary availability zone. Leave null for Azure to select."
  type        = string
  default     = null
  nullable    = true
}

variable "standby_availability_zone" {
  description = "Standby zone when high availability is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "public_network_access_enabled" {
  description = "Allow public access temporarily. Set false after private endpoint and private DNS are deployed."
  type        = bool
  default     = true
}

variable "firewall_rules" {
  description = "Explicit firewall rules for temporary public connectivity. Do not use broad rules in production."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}
}

variable "database_name" {
  description = "Application database name."
  type        = string
  default     = "agenticsre"
}

variable "entra_administrator_object_id" {
  description = "Object ID of the Entra user, group, or service principal designated as PostgreSQL administrator. Use an Entra group in production."
  type        = string
}

variable "entra_administrator_principal_name" {
  description = "Display name of the Entra administrator principal."
  type        = string
}

variable "entra_administrator_principal_type" {
  description = "Type of the Entra administrator principal."
  type        = string
  default     = "Group"

  validation {
    condition     = contains(["User", "Group", "ServicePrincipal"], var.entra_administrator_principal_type)
    error_message = "entra_administrator_principal_type must be User, Group, or ServicePrincipal."
  }
}

variable "log_analytics_workspace_id" {
  description = "Optional Log Analytics workspace ID for PostgreSQL diagnostics."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags applied to PostgreSQL."
  type        = map(string)
}
