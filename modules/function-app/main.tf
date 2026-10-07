resource "azurerm_storage_account" "function_host" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  tags                            = var.tags
}

resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = var.os_type
  sku_name            = var.service_plan_sku
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = var.application_insights_name
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  sampling_percentage = var.application_insights_sampling_percentage
  workspace_id        = var.log_analytics_workspace_id
  tags                = var.tags
}

locals {
  is_windows = var.os_type == "Windows"

  function_app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME                    = "dotnet-isolated"
      APPLICATIONINSIGHTS_CONNECTION_STRING       = azurerm_application_insights.this.connection_string
      EVENTHUB_FULLY_QUALIFIED_NAMESPACE          = var.event_hubs_fully_qualified_namespace
      EVENTHUB_NAME                               = var.event_hub_name
      EVENTHUB_CONSUMER_GROUP                     = var.event_hub_consumer_group
      EventHubConnection__fullyQualifiedNamespace = var.event_hubs_fully_qualified_namespace
      EventHubConnection__credential              = "managedidentity"
      FOUNDRY_PROJECT_ENDPOINT                    = var.foundry_project_endpoint
      FOUNDRY_ALERT_AGENT_NAME                    = var.foundry_alert_agent_name
      WEBSITE_RUN_FROM_PACKAGE                    = "1"
    },
    var.additional_app_settings,
  )
}

resource "azurerm_linux_function_app" "this" {
  count = local.is_windows ? 0 : 1

  name                        = var.function_app_name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  service_plan_id             = azurerm_service_plan.this.id
  storage_account_name        = azurerm_storage_account.function_host.name
  storage_account_access_key  = azurerm_storage_account.function_host.primary_access_key
  https_only                  = var.https_only
  functions_extension_version = "~4"
  tags                        = var.tags

  identity {
    type = "SystemAssigned"
  }

  app_settings = local.function_app_settings

  site_config {
    always_on                              = var.always_on
    ftps_state                             = var.ftps_state
    http2_enabled                          = var.http2_enabled
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    use_32_bit_worker                      = false
    application_insights_connection_string = azurerm_application_insights.this.connection_string

    application_stack {
      dotnet_version = "v8.0"
    }
  }

  lifecycle {
    precondition {
      condition     = length(trimspace(var.foundry_project_endpoint)) > 0
      error_message = "foundry_project_endpoint must be supplied; use a non-secret endpoint URL."
    }
  }
}

resource "azurerm_windows_function_app" "this" {
  count = local.is_windows ? 1 : 0

  name                        = var.function_app_name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  service_plan_id             = azurerm_service_plan.this.id
  storage_account_name        = azurerm_storage_account.function_host.name
  storage_account_access_key  = azurerm_storage_account.function_host.primary_access_key
  https_only                  = var.https_only
  functions_extension_version = "~4"
  tags                        = var.tags

  identity {
    type = "SystemAssigned"
  }

  app_settings = local.function_app_settings

  site_config {
    always_on                              = var.always_on
    ftps_state                             = var.ftps_state
    http2_enabled                          = var.http2_enabled
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    use_32_bit_worker                      = false
    application_insights_connection_string = azurerm_application_insights.this.connection_string
  }

  lifecycle {
    ignore_changes = [
      # Function deployment owns generated runtime settings and the Entra
      # provider secret. Keeping them outside state prevents Terraform from
      # exposing, deleting, or rotating an existing secret during adoption.
      app_settings,
      tags,
      builtin_logging_enabled,
      client_certificate_mode,
      ftp_publish_basic_authentication_enabled,
      webdeploy_publish_basic_authentication_enabled,
      auth_settings_v2,
      site_config[0].ip_restriction_default_action,
      site_config[0].scm_ip_restriction_default_action,
    ]

    precondition {
      condition     = length(trimspace(var.foundry_project_endpoint)) > 0
      error_message = "foundry_project_endpoint must be supplied; use a non-secret endpoint URL."
    }
  }
}

locals {
  function_app_id               = local.is_windows ? azurerm_windows_function_app.this[0].id : azurerm_linux_function_app.this[0].id
  function_app_name             = local.is_windows ? azurerm_windows_function_app.this[0].name : azurerm_linux_function_app.this[0].name
  function_app_default_hostname = local.is_windows ? azurerm_windows_function_app.this[0].default_hostname : azurerm_linux_function_app.this[0].default_hostname
  function_app_principal_id     = local.is_windows ? azurerm_windows_function_app.this[0].identity[0].principal_id : azurerm_linux_function_app.this[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "event_hubs_sender" {
  scope                = var.event_hub_id
  role_definition_name = "Azure Event Hubs Data Sender"
  principal_id         = local.function_app_principal_id
}

resource "azurerm_role_assignment" "event_hubs_receiver" {
  scope                = var.event_hub_id
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = local.function_app_principal_id
}

resource "azurerm_role_assignment" "foundry_invoker" {
  count = var.assign_foundry_invoker_role ? 1 : 0

  scope                = var.foundry_resource_id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = local.function_app_principal_id
}
