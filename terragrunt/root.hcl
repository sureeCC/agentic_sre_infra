# Shared provider and backend generation for every resource unit.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  config = local.common.locals.config
}

generate "providers" {
  path      = "terragrunt-providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
terraform {
  required_version = ">= 1.8.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}
provider "azurerm" {
  features {}
  subscription_id = "${local.config.subscription_id}"
  tenant_id       = "${local.config.tenant_id}"
}
provider "azuread" {
  tenant_id = "${local.config.tenant_id}"
}
EOF
}

remote_state {
  backend      = "azurerm"
  disable_init = true # State storage is bootstrapped separately; do not create it here.
  generate = {
    path      = "terragrunt-backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    # Existing Agentic SRE state storage. Environment variables override it in CI.
    resource_group_name  = get_env("TG_STATE_RESOURCE_GROUP", "test")
    storage_account_name = get_env("TG_STATE_STORAGE_ACCOUNT", "sttfstateagenticsre244b")
    container_name       = get_env("TG_STATE_CONTAINER", "tfstate")
    key                  = "agentic-sre/terragrunt/${replace(path_relative_to_include("root"), "\\", "/")}/terraform.tfstate"
    subscription_id      = get_env("TG_STATE_SUBSCRIPTION_ID", local.config.subscription_id)
    tenant_id            = get_env("TG_STATE_TENANT_ID", local.config.tenant_id)
    use_azuread_auth     = true
    use_oidc             = tobool(get_env("TG_USE_OIDC", "false"))
    use_cli              = !tobool(get_env("TG_USE_OIDC", "false"))
  }
}
