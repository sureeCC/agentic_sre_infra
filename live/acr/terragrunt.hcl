include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Containers/ACR" : "${include.common.locals.iac_modules_repo}//Containers/ACR?ref=${include.common.locals.module_ref}"
}
inputs = {
  acr_name                      = include.common.locals.names.acr
  acr_sku                       = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  pve_vnet_name                 = include.common.locals.environment.vnet_name
  pve_vnet_resource_group_name  = include.common.locals.environment.vnet_resource_group_name
  pve_subnet_name               = include.common.locals.environment.pve_subnet_name
}
