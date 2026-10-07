variable "name" {
  description = "Globally unique Azure AI Services / Foundry resource name."
  type        = string
}

variable "location" {
  description = "Azure region for the Foundry resource. Model availability must be confirmed in this region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group that contains the Foundry resource."
  type        = string
}

variable "sku_name" {
  description = "Azure AI Services SKU."
  type        = string
  default     = "S0"
}

variable "local_auth_enabled" {
  description = "Whether local key authentication is enabled on the Azure AI Services resource."
  type        = bool
  default     = false
}

variable "project_management_enabled" {
  description = "Whether Microsoft Foundry project management is enabled."
  type        = bool
  default     = false
}

variable "custom_subdomain_name" {
  description = "Unique subdomain for token-based Entra authentication and future private endpoints."
  type        = string
}

variable "create_model_deployment" {
  description = "Whether to create the model deployment. Set false when importing or consuming an existing deployment."
  type        = bool
  default     = false
}

variable "model_deployment_name" {
  description = "Name assigned to the Foundry model deployment."
  type        = string
  default     = "alert-agent-mini"
}

variable "model_format" {
  description = "Model provider format, for example OpenAI."
  type        = string
  default     = "OpenAI"
}

variable "model_name" {
  description = "Model name available in the selected Azure region."
  type        = string
  default     = "gpt-4.1-mini"
}

variable "model_version" {
  description = "Model version available in the selected Azure region."
  type        = string
  default     = "2025-04-14"
}

variable "model_sku_name" {
  description = "Model deployment SKU, for example GlobalStandard."
  type        = string
  default     = "GlobalStandard"
}

variable "model_sku_capacity" {
  description = "Initial deployment capacity. Confirm quota before enabling model deployment."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags applied to the Foundry resource."
  type        = map(string)
}
