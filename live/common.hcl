locals {
  project          = read_terragrunt_config(find_in_parent_folders("project.hcl")).locals
  context          = read_terragrunt_config(find_in_parent_folders("context.hcl")).locals
  env_config       = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  environment      = local.env_config.environment_overrides[local.context.environment]
  iac_modules_repo = local.project.iac_modules_repo
  module_ref       = local.project.module_ref
  # Match Shared/naming: prefix-environment-region-instance.
  name_suffix   = lower(join("-", [local.environment.env, local.environment.region, local.environment.instance]))
  app_name      = lower(local.project.app)
  unique_suffix = substr(replace(local.project.subscription_id, "-", ""), 0, 6)
  names = {
    acr                = lower(replace("acr${local.app_name}-${local.name_suffix}-${local.unique_suffix}", "/[^a-zA-Z0-9]/", ""))
    foundry            = "ai-${local.app_name}-${local.name_suffix}-${local.unique_suffix}"
    foundry_project    = "proj-${local.app_name}-${local.name_suffix}"
    eventhub_namespace = "ehns-${local.app_name}-${local.name_suffix}-${local.unique_suffix}"
    identity_prefix    = "mi-${local.app_name}"
    # Keep the complete Key Vault name within its 24-character limit.
    keyvault_prefix = "kv-sre-${substr(local.unique_suffix, 0, 4)}"
    postgres_prefix = "pg-sre-${local.unique_suffix}"
  }
}
inputs = {
  subscription_id     = local.project.subscription_id
  resource_group_name = local.environment.resource_group_name
  location            = local.environment.location
  app                 = local.project.app
  env                 = local.environment.env
  region              = local.environment.region
  instance            = local.environment.instance
  owner               = local.project.owner
  deployment_method   = "Terragrunt"
  provisioned_time    = local.project.provisioned_time
  tags = {
    Workload  = "AgenticSRE"
    ManagedBy = "Terragrunt"
  }
}
