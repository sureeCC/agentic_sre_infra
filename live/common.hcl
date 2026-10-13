locals {
  project          = read_terragrunt_config(find_in_parent_folders("project.hcl")).locals
  context          = read_terragrunt_config(find_in_parent_folders("context.hcl")).locals
  env_config       = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  environment      = local.env_config.environment_overrides[local.context.environment]
  iac_modules_repo = local.project.iac_modules_repo
  module_ref       = local.project.module_ref
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
