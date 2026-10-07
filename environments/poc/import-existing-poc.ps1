# Imports existing POC resources into the configured Terraform backend.
# This changes Terraform state only; it does not create, update, or delete Azure resources.
# Run from this directory after `terraform init` succeeds.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$subscriptionId = "244b1140-2e3c-4232-8c86-2b77c04ca37e"
$resourceGroup = "test"

function Import-IfMissing {
  param(
    [Parameter(Mandatory)] [string] $Address,
    [Parameter(Mandatory)] [string] $ResourceId
  )

  $currentState = @(terraform state list)
  if ($currentState -contains $Address) {
    Write-Host "Already imported: $Address" -ForegroundColor DarkGray
    return
  }

  # Terraform on Windows requires literal quotes in for_each addresses to be
  # escaped once before passing through PowerShell.
  $terraformAddress = $Address -replace '"', '\"'
  Write-Host "Importing: $Address" -ForegroundColor Cyan
  terraform import $terraformAddress $ResourceId
  if ($LASTEXITCODE -ne 0) {
    throw "Terraform import failed for $Address."
  }
}

$baseId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup"

$imports = @(
  @{ Address = "module.resource_group.azurerm_resource_group.this"; Id = $baseId },
  @{ Address = "module.event_hubs.azurerm_eventhub_namespace.this"; Id = "$baseId/providers/Microsoft.EventHub/namespaces/pocagenticsre" },
  @{ Address = 'module.event_hubs.azurerm_eventhub.this["testeventhub"]'; Id = "$baseId/providers/Microsoft.EventHub/namespaces/pocagenticsre/eventhubs/testeventhub" },
  @{ Address = "module.foundry.azurerm_cognitive_account.this"; Id = "$baseId/providers/Microsoft.CognitiveServices/accounts/agenticsre" },
  @{ Address = "module.function_app.azurerm_storage_account.function_host"; Id = "$baseId/providers/Microsoft.Storage/storageAccounts/stfuncagentsre244b" },
  # Azure CLI can display this segment as serverfarms, but the Terraform
  # importer requires the canonical ARM casing: serverFarms.
  @{ Address = "module.function_app.azurerm_service_plan.this"; Id = "$baseId/providers/Microsoft.Web/serverFarms/WestUSPlan" },
  @{ Address = "module.function_app.azurerm_application_insights.this"; Id = "$baseId/providers/Microsoft.Insights/components/func-agenticsre-poc-244b" },
  @{ Address = "module.function_app.azurerm_windows_function_app.this[0]"; Id = "$baseId/providers/Microsoft.Web/sites/func-agenticsre-poc-244b" },
  @{ Address = "module.postgresql.azurerm_postgresql_flexible_server.this"; Id = "$baseId/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-agenticsre-poc-244b" },
  @{ Address = "module.postgresql.azurerm_postgresql_flexible_server_database.this"; Id = "$baseId/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-agenticsre-poc-244b/databases/agenticsre" },
  @{ Address = "module.postgresql.azurerm_postgresql_flexible_server_active_directory_administrator.this"; Id = "$baseId/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-agenticsre-poc-244b/administrators/e1db7ae1-32c8-47da-b760-749afb295698" },
  # Microsoft Entra application object IDs (not client/application IDs).
  @{ Address = "module.app_registrations.azuread_application.function_api"; Id = "/applications/a9ca2541-275d-4a02-bd7b-bbdcd2ceaf41" },
  @{ Address = "module.app_registrations.azuread_application.kibana_client"; Id = "/applications/0a1b7407-5181-4bb4-a13e-0468599c087a" },
  @{ Address = "module.app_registrations.azuread_service_principal.function_api"; Id = "/servicePrincipals/a0c39ca6-5bd1-41c2-923e-e5c76da280a9" },
  @{ Address = "module.app_registrations.azuread_service_principal.kibana_client"; Id = "/servicePrincipals/45549217-6817-4817-b665-d928551686b8" },
  # Existing Kibana-to-ingress API role grant. Its assignment ID is opaque.
  @{ Address = "module.app_registrations.azuread_app_role_assignment.kibana_alert_send"; Id = "/servicePrincipals/a0c39ca6-5bd1-41c2-923e-e5c76da280a9/appRoleAssignedTo/F5JURRdoF0i2ZdkoVRaGuMeddc-dU35Ap-kSGxVx9sA" },
  @{ Address = "module.function_app.azurerm_role_assignment.event_hubs_sender"; Id = "$baseId/providers/Microsoft.EventHub/namespaces/pocagenticsre/eventhubs/testeventhub/providers/Microsoft.Authorization/roleAssignments/9d072c0d-30ef-4541-abb7-563f3a7f6b4e" },
  @{ Address = "module.function_app.azurerm_role_assignment.event_hubs_receiver"; Id = "$baseId/providers/Microsoft.EventHub/namespaces/pocagenticsre/eventhubs/testeventhub/providers/Microsoft.Authorization/roleAssignments/d39fedac-c1e5-47db-a31f-3ec5d51f2256" }
)

$firewallRules = @(
  "allow-azure-services-poc",
  "codex-bootstrap-workstation",
  "function-outbound-104-45-212-38",
  "function-outbound-104-45-214-17",
  "function-outbound-104-45-215-181",
  "function-outbound-104-45-215-185",
  "function-outbound-104-45-216-224",
  "function-outbound-104-45-222-185",
  "function-outbound-40-112-243-96",
  "laptop-vscode"
)

foreach ($ruleName in $firewallRules) {
  $imports += @{
    Address = "module.postgresql.azurerm_postgresql_flexible_server_firewall_rule.this[`"$ruleName`"]"
    Id      = "$baseId/providers/Microsoft.DBforPostgreSQL/flexibleServers/pg-agenticsre-poc-244b/firewallRules/$ruleName"
  }
}

foreach ($item in $imports) {
  Import-IfMissing -Address $item.Address -ResourceId $item.Id
}

Write-Host "Import pass complete. Next run: terraform plan" -ForegroundColor Green
