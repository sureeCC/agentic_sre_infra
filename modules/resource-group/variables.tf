variable "name" {
  description = "Name of the Azure Resource Group."
  type        = string

  validation {
    condition     = can(regex("^[-\\w().]{1,90}$", var.name))
    error_message = "Resource Group name must be 1-90 valid Azure Resource Manager characters."
  }
}

variable "location" {
  description = "Azure region for the Resource Group."
  type        = string

  validation {
    condition     = length(trimspace(var.location)) > 0
    error_message = "location must not be empty."
  }
}

variable "tags" {
  description = "Mandatory governance tags applied to the Resource Group."
  type        = map(string)
}

variable "enforce_required_tags" {
  description = "Require standard governance tags. Disable only while importing an existing untagged environment."
  type        = bool
  default     = true
}
