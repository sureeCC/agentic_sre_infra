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

generate "private_dns" {
  path      = "private-dns.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile("${get_terragrunt_dir()}/../_templates/private-dns.tf.tftpl", {
    zone_id_link = false
    zones        = jsonencode(["privatelink.vaultcore.azure.net"])
    link_name    = jsonencode("link-${include.common.locals.name_suffix}")
    vnet_id      = jsonencode("/subscriptions/${include.common.inputs.subscription_id}/resourceGroups/${include.common.locals.environment.vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${include.common.locals.environment.vnet_name}")
  })
}
generate "private_dns_endpoint" {
  path      = "private-dns_override.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile("${get_terragrunt_dir()}/../_templates/private-dns-override.tf.tftpl", {
    endpoint_resource = "pep_st"
  })
}
