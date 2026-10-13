# Application deployment pipelines

Infrastructure is managed by `.github/workflows/infrastructure.yml` using the units under `live/`. See [infrastructure setup](INFRASTRUCTURE-SETUP.md). The application workflows below build or package on relevant pull requests and deploy only on a manual run from `main`.

## Function alert bridge

Workflow: `.github/workflows/function-app.yml`.

The .NET 8 build creates and verifies a Functions package. Deployment uses the existing Function App selected by the `function-poc` GitHub environment. Configure its `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP` and `FUNCTION_APP_NAME` variables, OIDC federation and appropriate deployment permissions.

The Function App must already exist. Configure mandatory Entra App Service Authentication, the `Kibana.Alert.Send` application role, runtime settings, Event Hubs settings, Foundry endpoint and managed-identity permissions before deployment. The workflow checks ingress authentication and verifies both function triggers after deployment. It does not provision hosting or grant application roles. See the [application README](../applications/function-alert-bridge/README.md).

## Foundry hosted alert agent

Workflow: `.github/workflows/ai-agent.yml`.

The package job checks Python dependencies and packages source with `scripts/ci/package-agent.py`. Deployment uses `scripts/ci/deploy-agent.py`, creates an agent version and waits for active provisioning.

Configure the `agent-poc` GitHub environment with the three Azure identity variables, OIDC federation, project deployment permissions and:

| Variable | Purpose |
|---|---|
| `FOUNDRY_PROJECT_ENDPOINT` | Existing Foundry project HTTPS endpoint |
| `FOUNDRY_AGENT_NAME` | Agent name matching the Function application setting |
| `AZURE_AI_MODEL_DEPLOYMENT_NAME` | Existing model deployment name |
| `POSTGRES_HOST`, `POSTGRES_DATABASE` | Database connection target |
| `POSTGRES_AAD_USER` | Provisioned Entra database role for the agent |
| `AGENT_CPU`, `AGENT_MEMORY` | Supported hosted-agent resource tier |

The agent code expects Entra authentication to PostgreSQL. The current database infrastructure uses password authentication; enable and configure Entra access before running this application. Create the database role, required table and permissions separately. Active provisioning does not prove model inference or database writes work. See the [agent README](../applications/foundry-hosted-alert-agent/README.md).

## Deployment order

Provision and review infrastructure, complete private DNS and application network connectivity, configure database authentication/schema/permissions, deploy the agent, configure Function hosting/authentication/settings, then deploy the Function. The workflows do not automatically trigger each other. A GitHub-hosted runner cannot directly reach private service endpoints without appropriate private network connectivity.