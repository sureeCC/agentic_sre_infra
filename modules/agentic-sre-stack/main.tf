module "resource_group" {
  source = "../resource-group"

  name                  = var.resource_group_name
  location              = var.resource_group_location
  tags                  = local.effective_tags
  enforce_required_tags = var.manage_tags
}

module "event_hubs" {
  source = "../event-hubs"

  namespace_name                = var.event_hubs_namespace_name
  location                      = var.location
  resource_group_name           = module.resource_group.name
  sku                           = var.event_hubs_sku
  capacity                      = var.event_hubs_capacity
  auto_inflate_enabled          = var.event_hubs_auto_inflate_enabled
  maximum_throughput_units      = var.event_hubs_maximum_throughput_units
  local_authentication_enabled  = var.event_hubs_local_authentication_enabled
  public_network_access_enabled = var.event_hubs_public_network_access_enabled
  event_hubs                    = var.event_hubs
  log_analytics_workspace_id    = var.log_analytics_workspace_id
  tags                          = local.effective_tags
}

module "function_app" {
  source = "../function-app"

  function_app_name                        = var.function_app_name
  service_plan_name                        = var.function_service_plan_name
  service_plan_sku                         = var.function_service_plan_sku
  os_type                                  = var.function_os_type
  https_only                               = var.function_https_only
  always_on                                = var.function_always_on
  ftps_state                               = var.function_ftps_state
  http2_enabled                            = var.function_http2_enabled
  storage_account_name                     = var.function_storage_account_name
  storage_replication_type                 = var.function_storage_replication_type
  application_insights_name                = var.application_insights_name
  application_insights_sampling_percentage = var.application_insights_sampling_percentage
  resource_group_name                      = module.resource_group.name
  location                                 = var.location
  event_hub_id                             = module.event_hubs.event_hub_ids[var.function_event_hub_name]
  event_hubs_fully_qualified_namespace     = module.event_hubs.fully_qualified_namespace
  event_hub_name                           = var.function_event_hub_name
  event_hub_consumer_group                 = var.function_event_hub_consumer_group
  foundry_project_endpoint                 = var.foundry_project_endpoint
  foundry_alert_agent_name                 = var.foundry_alert_agent_name
  foundry_resource_id                      = module.foundry.id
  assign_foundry_invoker_role              = var.function_assign_foundry_invoker_role
  log_analytics_workspace_id               = var.log_analytics_workspace_id
  additional_app_settings                  = var.function_additional_app_settings
  tags                                     = local.effective_tags
}

module "foundry" {
  source = "../foundry"

  name                       = var.foundry_resource_name
  location                   = var.location
  resource_group_name        = module.resource_group.name
  sku_name                   = var.foundry_sku_name
  local_auth_enabled         = var.foundry_local_auth_enabled
  project_management_enabled = var.foundry_project_management_enabled
  custom_subdomain_name      = var.foundry_custom_subdomain_name
  create_model_deployment    = var.foundry_create_model_deployment
  model_deployment_name      = var.foundry_model_deployment_name
  model_format               = var.foundry_model_format
  model_name                 = var.foundry_model_name
  model_version              = var.foundry_model_version
  model_sku_name             = var.foundry_model_sku_name
  model_sku_capacity         = var.foundry_model_sku_capacity
  tags                       = local.effective_tags
}

module "postgresql" {
  source = "../postgresql"

  server_name                        = var.postgresql_server_name
  resource_group_name                = module.resource_group.name
  location                           = var.location
  tenant_id                          = var.tenant_id
  sku_name                           = var.postgresql_sku_name
  postgresql_version                 = var.postgresql_version
  storage_mb                         = var.postgresql_storage_mb
  backup_retention_days              = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled       = var.postgresql_geo_redundant_backup_enabled
  high_availability_enabled          = var.postgresql_high_availability_enabled
  zone                               = var.postgresql_zone
  standby_availability_zone          = var.postgresql_standby_availability_zone
  public_network_access_enabled      = var.postgresql_public_network_access_enabled
  firewall_rules                     = var.postgresql_firewall_rules
  database_name                      = var.postgresql_database_name
  entra_administrator_object_id      = var.postgresql_entra_administrator_object_id
  entra_administrator_principal_name = var.postgresql_entra_administrator_principal_name
  entra_administrator_principal_type = var.postgresql_entra_administrator_principal_type
  log_analytics_workspace_id         = var.log_analytics_workspace_id
  tags                               = var.postgresql_tags == null ? local.effective_tags : var.postgresql_tags
}

module "app_registrations" {
  source = "../app-registrations"

  function_api_display_name                 = var.function_api_display_name
  function_api_identifier_uri               = var.function_api_identifier_uri
  kibana_client_display_name                = var.kibana_client_display_name
  kibana_alert_send_role_id                 = var.kibana_alert_send_role_id
  access_token_version                      = var.app_registration_access_token_version
  kibana_alert_send_role_description        = var.app_registration_kibana_role_description
  kibana_alert_send_role_display_name       = var.app_registration_kibana_role_display_name
  manage_owners                             = var.app_registration_manage_owners
  enterprise_feature_tag_enabled            = var.app_registration_enterprise_feature_tag_enabled
  function_api_app_role_assignment_required = var.app_registration_function_api_assignment_required
  manage_kibana_required_resource_access    = var.app_registration_manage_kibana_required_resource_access
}

locals {
  required_tags = merge(
    {
      environment         = var.environment
      workload            = "agentic-sre"
      owner               = var.owner
      cost_center         = var.cost_center
      data_classification = var.data_classification
      managed_by          = "terraform"
    },
    var.additional_tags,
  )

  effective_tags = var.manage_tags ? local.required_tags : {}
}
