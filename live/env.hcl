locals {
  environment_overrides = {
    for name in ["dev", "qa", "prod"] : name => {
      env                         = name
      subscription_id             = get_env("ARM_SUBSCRIPTION_ID")
      location                    = get_env("LOCATION")
      region                      = get_env("REGION")
      instance                    = get_env("INSTANCE")
      resource_group_name         = get_env("RESOURCE_GROUP_NAME")
      vnet_name                   = get_env("VNET_NAME")
      vnet_resource_group_name    = get_env("VNET_RESOURCE_GROUP_NAME")
      pve_subnet_name             = get_env("PVE_SUBNET_NAME")
      svc_subnet_name             = get_env("SVC_SUBNET_NAME")
      postgres_dns_zone_name      = get_env("POSTGRES_DNS_ZONE_NAME")
      postgres_dns_resource_group = get_env("POSTGRES_DNS_RESOURCE_GROUP")
      model_name                  = get_env("MODEL_NAME")
      model_version               = get_env("MODEL_VERSION")
      acr_name                    = get_env("ACR_NAME")
      foundry_name                = get_env("FOUNDRY_NAME")
      foundry_project_name        = get_env("FOUNDRY_PROJECT_NAME")
      eventhub_namespace_name     = get_env("EVENTHUB_NAMESPACE_NAME")
      model_capacity              = tonumber(get_env("MODEL_CAPACITY", "1"))
    }
  }
}
