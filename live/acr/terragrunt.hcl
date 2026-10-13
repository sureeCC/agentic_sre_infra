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

generate "private_dns" {
  path      = "private-dns.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile("${get_terragrunt_dir()}/../_templates/private-dns.tf.tftpl", {
    zones     = jsonencode(["privatelink.azurecr.io"])
    link_name = jsonencode("link-${include.common.locals.name_suffix}")
    vnet_id   = jsonencode("/subscriptions/${include.common.inputs.subscription_id}/resourceGroups/${include.common.locals.environment.vnet_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${include.common.locals.environment.vnet_name}")
  })
}
generate "private_dns_endpoint" {
  path      = "private-dns_override.tf"
  if_exists = "overwrite_terragrunt"
  contents = templatefile("${get_terragrunt_dir()}/../_templates/private-dns-override.tf.tftpl", {
    endpoint_resource = "pvtep_ace"
  })
}
