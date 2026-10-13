# Application deployment prerequisites

Target: personal subscription `244b1140-2e3c-4232-8c86-2b77c04ca37e`, Dev resource group `rg-ips-multiagenticai-sre-dev`, West US. The six infrastructure units are managed independently under `live/`. Deploying these units does not deploy application hosting.

## Application targets

| Setting | Dev value |
|---|---|
| Foundry account | `ai-agenticsre-dev-wus-002-244b11` |
| Foundry project | `proj-agenticsre-dev-wus-002` |
| Model deployment | `alert-agent-mini` |
| Container registry | `acragenticsredevwus001244b11.azurecr.io` |
| Event Hub namespace | `ehns-agenticsre-dev-wus-001-244b11.servicebus.windows.net` |
| Event Hub | `eh-alerts-dev-wus-001` |
| Consumer group | `imo` |
| PostgreSQL host | `pg-sre-244b11-dev-wus-001.postgres.database.azure.com` |
| Database | `agenticsre` |
| Runtime user-assigned identity | `mi-agenticsre-dev-wus-001` |

The project endpoint is `https://ai-agenticsre-dev-wus-002-244b11.services.ai.azure.com/api/projects/proj-agenticsre-dev-wus-002`.

## Work remaining before application deployment

1. Provision Function hosting, its runtime identity and VNet integration. Configure Entra ingress authentication and the application settings consumed by `applications/function-alert-bridge`.
2. Configure Foundry hosted-agent networking that can reach the private PostgreSQL server. A private endpoint handles inbound traffic; it does not automatically give hosted agents outbound VNet access.
3. Enable PostgreSQL Entra authentication, configure an Entra administrator, and create/grant the database role for the actual agent runtime identity. The current server uses password authentication; the Python application expects Entra token authentication.
4. Assign service-scoped runtime permissions: Event Hub sender/receiver, Foundry access, ACR pull and Key Vault secret access as required by each application identity. Creating a managed identity alone grants no data access.
5. Configure `function-poc` and `agent-poc` GitHub Environments, their OIDC federated credentials, deployment permissions and the variables referenced by the application workflows.
6. Use a runner/network path that can reach private deployment and application endpoints. Verify private DNS resolution and actual service requests from that network before testing the alert flow.

Keep Azure authentication on managed identity/OIDC. The infrastructure PostgreSQL bootstrap password remains a GitHub Environment secret; it is not an Azure authentication client secret. Backend storage remains accessible to the pipeline using Entra authentication and container-scoped blob permissions.

Foundry bootstrap access was configured on the replacement account: Foundry User for the project's system-assigned identity, `mi-agenticsre-dev-wus-001`, and the personal Azure user. These account-scoped assignments were created with the personal administrator, outside Terraform. If either runtime identity is replaced, reconcile its permissions. Event Hub, ACR, Key Vault and database runtime grants remain part of the application stage; the pipeline identity has not been given role-assignment administration.
