include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//app-registrations${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
}

inputs = {
  function_api_display_name                 = "agenticsre-kibana-ingress-api"
  function_api_identifier_uri               = "api://052b5b68-f1aa-4a9f-b975-8e743f359565"
  kibana_client_display_name                = "agenticsre-kibana-webhook-client"
  kibana_alert_send_role_id                 = "4c9cd731-8f05-4f18-89ca-42c62c0f4150"
  access_token_version                      = 1
  kibana_alert_send_role_description        = "Allows Kibana to send alert events to the ingress API."
  kibana_alert_send_role_display_name       = "Kibana.Alert.Send"
  manage_owners                             = false
  enterprise_feature_tag_enabled            = false
  function_api_app_role_assignment_required = false
  manage_kibana_required_resource_access    = false
}
