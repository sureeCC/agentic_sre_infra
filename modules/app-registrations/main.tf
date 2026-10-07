data "azuread_client_config" "current" {}

resource "azuread_application" "function_api" {
  display_name     = var.function_api_display_name
  identifier_uris  = [var.function_api_identifier_uri]
  sign_in_audience = "AzureADMyOrg"
  owners           = var.manage_owners ? [data.azuread_client_config.current.object_id] : null

  api {
    requested_access_token_version = var.access_token_version
  }

  app_role {
    allowed_member_types = ["Application"]
    description          = var.kibana_alert_send_role_description
    display_name         = var.kibana_alert_send_role_display_name
    enabled              = true
    id                   = var.kibana_alert_send_role_id
    value                = "Kibana.Alert.Send"
  }

  feature_tags {
    enterprise = var.enterprise_feature_tag_enabled
  }
}

resource "azuread_service_principal" "function_api" {
  client_id                    = azuread_application.function_api.client_id
  app_role_assignment_required = var.function_api_app_role_assignment_required
  owners                       = var.manage_owners ? [data.azuread_client_config.current.object_id] : null
}

resource "azuread_application" "kibana_client" {
  display_name     = var.kibana_client_display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = var.manage_owners ? [data.azuread_client_config.current.object_id] : null

  dynamic "required_resource_access" {
    for_each = var.manage_kibana_required_resource_access ? [1] : []

    content {
      resource_app_id = azuread_application.function_api.client_id

      resource_access {
        id   = var.kibana_alert_send_role_id
        type = "Role"
      }
    }
  }

  feature_tags {
    enterprise = var.enterprise_feature_tag_enabled
  }
}

resource "azuread_service_principal" "kibana_client" {
  client_id = azuread_application.kibana_client.client_id
  owners    = var.manage_owners ? [data.azuread_client_config.current.object_id] : null
}

resource "azuread_app_role_assignment" "kibana_alert_send" {
  app_role_id         = var.kibana_alert_send_role_id
  principal_object_id = azuread_service_principal.kibana_client.object_id
  resource_object_id  = azuread_service_principal.function_api.object_id
}
