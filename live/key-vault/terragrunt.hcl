include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Security/Keyvault" : "${include.common.locals.iac_modules_repo}//Security/Keyvault?ref=${include.common.locals.module_ref}"
}
inputs = {
  resource_prefix               = include.common.locals.names.keyvault_prefix
  sku_name                      = "standard"
  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  vnet_name                     = include.common.locals.environment.vnet_name
  vnet_resource_group_name      = include.common.locals.environment.vnet_resource_group_name
  subnet_name                   = include.common.locals.environment.pve_subnet_name
  key_permissions               = []
  secret_permissions            = []
  storage_permissions           = []
  key_name                      = {}
}
