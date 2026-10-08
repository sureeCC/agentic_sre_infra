include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${get_terragrunt_dir()}/common.hcl"
  expose = true
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//agentic-sre-stack"
}

inputs = merge(jsondecode(<<-JSON
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "tenant_id": "00000000-0000-0000-0000-000000000000",
  "environment": "prod",
  "resource_group_name": "rg-agenticsre-prod-example",
  "location": "westus",
  "resource_group_location": "westus",
  "owner": "platform-engineering",
  "cost_center": "REPLACE_WITH_PRODUCTION_COST_CENTER",
  "data_classification": "internal",
  "manage_tags": true,
  "event_hubs_namespace_name": "ehns-agenticsre-prod-example",
  "event_hubs": {
    "alerts": {
      "partition_count": 4,
      "message_retention_days": 7,
      "consumer_groups": ["foundry-agent-dispatcher"]
    }
  },
  "function_app_name": "func-agenticsre-prod-example",
  "function_service_plan_name": "plan-agenticsre-prod-example",
  "function_storage_account_name": "stagentprodexample",
  "application_insights_name": "appi-agenticsre-prod-example",
  "function_event_hub_name": "alerts",
  "function_os_type": "Linux",
  "foundry_project_endpoint": "https://REPLACE.services.ai.azure.com/api/projects/REPLACE",
  "foundry_alert_agent_name": "sre-alert-postgres-hosted",
  "foundry_resource_name": "ai-agenticsre-prod-example",
  "foundry_custom_subdomain_name": "ai-agenticsre-prod-example",
  "foundry_create_model_deployment": false,
  "function_api_identifier_uri": "api://REPLACE_WITH_VERIFIED_PRODUCTION_API_URI",
  "kibana_alert_send_role_id": "11111111-2222-3333-4444-555555555555",
  "app_registration_access_token_version": 2,
  "app_registration_kibana_role_description": "Allows Kibana to submit alerts",
  "app_registration_kibana_role_display_name": "Send Kibana alerts",
  "app_registration_manage_owners": false,
  "app_registration_enterprise_feature_tag_enabled": true,
  "app_registration_function_api_assignment_required": true,
  "app_registration_manage_kibana_required_resource_access": true,
  "postgresql_server_name": "pg-agenticsre-prod-example",
  "postgresql_entra_administrator_object_id": "00000000-0000-0000-0000-000000000000",
  "postgresql_entra_administrator_principal_name": "agenticsre-prod-db-admins",
  "postgresql_entra_administrator_principal_type": "Group",
  "postgresql_sku_name": "GP_Standard_D2s_v3",
  "postgresql_backup_retention_days": 35,
  "postgresql_high_availability_enabled": true,
  "postgresql_zone": "1",
  "postgresql_standby_availability_zone": "2",
  "postgresql_public_network_access_enabled": true,
  "postgresql_firewall_rules": {}
}

JSON
  ), include.common.locals.config, {
  postgresql_entra_administrator_object_id = get_env("TG_PROD_POSTGRES_ADMIN_OBJECT_ID")
  foundry_project_endpoint                 = get_env("TG_PROD_FOUNDRY_PROJECT_ENDPOINT")
  function_api_identifier_uri              = get_env("TG_PROD_FUNCTION_API_IDENTIFIER_URI")
  kibana_alert_send_role_id                = get_env("TG_PROD_KIBANA_ALERT_SEND_ROLE_ID")
  postgresql_firewall_rules                = jsondecode(get_env("TG_PROD_POSTGRES_FIREWALL_RULES"))
})
