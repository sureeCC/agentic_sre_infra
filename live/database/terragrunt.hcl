include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Databases/PostgreSQL-Flexible-Server" : "${include.common.locals.iac_modules_repo}//Databases/PostgreSQL-Flexible-Server?ref=${include.common.locals.module_ref}"
}
inputs = {
  resource_prefix = "pg-sre"
  postgresql_flexible_servers = {
    primary = {
      sku_name                        = "B_Standard_B1ms"
      administrator_login             = "sreadmin"
      administrator_password          = get_env("POSTGRES_ADMIN_PASSWORD")
      version                         = "16"
      storage_mb                      = 32768
      backup_retention_days           = 7
      public_network_access_enabled   = false
      delegated_subnet_name           = include.common.locals.environment.svc_subnet_name
      delegated_subnet_resource_group = include.common.locals.environment.vnet_resource_group_name
      delegated_vnet_name             = include.common.locals.environment.vnet_name
      private_dns_zone_name           = include.common.locals.environment.postgres_dns_zone_name
      private_dns_zone_resource_group = include.common.locals.environment.postgres_dns_resource_group
      databases                       = { agenticsre = { charset = "UTF8", collation = "en_US.utf8" } }
    }
  }
}
