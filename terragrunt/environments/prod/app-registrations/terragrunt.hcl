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
  function_api_display_name                 = "agentic-sre-alert-api"
  function_api_identifier_uri               = get_env("TG_PROD_FUNCTION_API_IDENTIFIER_URI")
  kibana_client_display_name                = "kibana-alerting-client"
  kibana_alert_send_role_id                 = get_env("TG_PROD_KIBANA_ALERT_SEND_ROLE_ID")
  access_token_version                      = 2
  kibana_alert_send_role_description        = "Allows Kibana to submit alerts"
  kibana_alert_send_role_display_name       = "Send Kibana alerts"
  manage_owners                             = false
  enterprise_feature_tag_enabled            = true
  function_api_app_role_assignment_required = true
  manage_kibana_required_resource_access    = true
}
