locals {
  context = read_terragrunt_config(find_in_parent_folders("context.hcl")).locals
  project = read_terragrunt_config(find_in_parent_folders("project.hcl")).locals
}
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = local.project.state_resource_group
    storage_account_name = local.project.state_storage_account
    container_name       = local.project.state_container
    key                  = "${local.context.repo_name}/${path_relative_to_include("root")}/${local.context.environment}/terraform.tfstate"
    subscription_id      = local.project.subscription_id
    tenant_id            = local.project.tenant_id
    use_azuread_auth     = true
    use_oidc             = get_env("GITHUB_ACTIONS", "false") == "true"
    use_cli              = get_env("GITHUB_ACTIONS", "false") != "true"
  }
}
