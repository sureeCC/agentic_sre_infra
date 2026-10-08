include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//postgresql${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
}

dependency "resource_group" {
  # Validation checks schemas without requiring migrated upstream state.
  skip_outputs                            = get_terraform_command() == "validate"
  mock_outputs_allowed_terraform_commands = ["validate"]
  mock_outputs = {
    name = include.common.locals.resource_group_name
  }
  config_path = "../resource-group"
}

inputs = {
  server_name                   = "pg-agenticsre-poc-244b"
  resource_group_name           = dependency.resource_group.outputs.name
  location                      = include.common.locals.location
  tenant_id                     = include.common.locals.tenant_id
  sku_name                      = "B_Standard_B1ms"
  postgresql_version            = "16"
  storage_mb                    = 32768
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  high_availability_enabled     = false
  zone                          = null
  standby_availability_zone     = null
  public_network_access_enabled = true
  firewall_rules = {
    "allow-azure-services-poc" = {
      "end_ip_address"   = "0.0.0.0"
      "start_ip_address" = "0.0.0.0"
    }
    "codex-bootstrap-workstation" = {
      "end_ip_address"   = "182.156.9.21"
      "start_ip_address" = "182.156.9.21"
    }
    "function-outbound-104-45-212-38" = {
      "end_ip_address"   = "104.45.212.38"
      "start_ip_address" = "104.45.212.38"
    }
    "function-outbound-104-45-214-17" = {
      "end_ip_address"   = "104.45.214.17"
      "start_ip_address" = "104.45.214.17"
    }
    "function-outbound-104-45-215-181" = {
      "end_ip_address"   = "104.45.215.181"
      "start_ip_address" = "104.45.215.181"
    }
    "function-outbound-104-45-215-185" = {
      "end_ip_address"   = "104.45.215.185"
      "start_ip_address" = "104.45.215.185"
    }
    "function-outbound-104-45-216-224" = {
      "end_ip_address"   = "104.45.216.224"
      "start_ip_address" = "104.45.216.224"
    }
    "function-outbound-104-45-222-185" = {
      "end_ip_address"   = "104.45.222.185"
      "start_ip_address" = "104.45.222.185"
    }
    "function-outbound-40-112-243-96" = {
      "end_ip_address"   = "40.112.243.96"
      "start_ip_address" = "40.112.243.96"
    }
    "laptop-vscode" = {
      "end_ip_address"   = "27.5.183.121"
      "start_ip_address" = "27.5.183.121"
    }
  }
  database_name                      = "agenticsre"
  entra_administrator_object_id      = "e1db7ae1-32c8-47da-b760-749afb295698"
  entra_administrator_principal_name = "suresh selvam"
  entra_administrator_principal_type = "User"
  log_analytics_workspace_id         = include.common.locals.log_analytics_workspace_id
  tags = {
    "CostProfile" = "minimum"
    "Environment" = "POC"
    "Workload"    = "agentic-sre"
  }
}
