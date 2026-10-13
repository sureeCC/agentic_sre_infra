locals {
  iac_modules_repo      = get_env("IAC_MODULES_REPO", "git::https://github.com/sureeCC/agentic_sre_modules.git")
  module_ref            = get_env("MODULE_REF", "89ca9b8386158ced7f517e9a8f407f70476666d1")
  subscription_id       = get_env("ARM_SUBSCRIPTION_ID")
  tenant_id             = get_env("ARM_TENANT_ID")
  app                   = get_env("APP")
  owner                 = get_env("OWNER")
  provisioned_time      = get_env("PROVISIONED_TIME")
  state_resource_group  = get_env("STATE_RESOURCE_GROUP")
  state_storage_account = get_env("STATE_STORAGE_ACCOUNT")
  state_container       = get_env("STATE_CONTAINER")
}
