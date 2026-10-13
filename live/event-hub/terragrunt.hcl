include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Messaging-and-notifications/Event-Hub" : "${include.common.locals.iac_modules_repo}//Messaging-and-notifications/Event-Hub?ref=${include.common.locals.module_ref}"
}
inputs = {
  resource_prefix               = "eh-alerts"
  eventhub_namespace_name       = include.common.locals.names.eventhub_namespace
  namespace_sku                 = "Standard"
  capacity                      = 1
  auto_inflate_enabled          = false
  local_authentication_enabled  = false
  public_network_access_enabled = false
  enable_private_endpoint       = true
  vnet_name                     = include.common.locals.environment.vnet_name
  vnet_resource_group_name      = include.common.locals.environment.vnet_resource_group_name
  subnet_name                   = include.common.locals.environment.pve_subnet_name
  event_hubs = {
    alerts = {
      partition_count   = 2
      message_retention = 1
      consumer_groups   = [{ custom_name = "imo" }]
      status            = "Active"
    }
  }
}
