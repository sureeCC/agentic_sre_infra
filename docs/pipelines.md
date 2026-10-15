# Application deployment pipelines

Infrastructure is managed by `.github/workflows/infrastructure.yml` using the units under `live/`. See [infrastructure setup](INFRASTRUCTURE-SETUP.md). The application workflows below build or package on relevant pull requests and deploy only on a manual run from `main`.

## Function alert bridge

Workflow: `.github/workflows/function-app.yml`.

The .NET 8 build creates and verifies a Functions package. Deployment uses the existing Function App selected by the `function-poc` GitHub environment. Configure its `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP` and `FUNCTION_APP_NAME` variables, OIDC federation and appropriate deployment permissions.

The Function App must already exist. Configure mandatory Entra App Service Authentication, the `Kibana.Alert.Send` application role, runtime settings, Event Hubs settings, Foundry endpoint and managed-identity permissions before deployment. The workflow checks ingress authentication and verifies both function triggers after deployment. It does not provision hosting or grant application roles. See the [application README](../applications/function-alert-bridge/README.md).

## Foundry hosted alert agent

PR validation: `.github/workflows/ai-agent.yml` runs offline deployment tests, builds
and validates the Linux Docker image without Azure credentials or deployment.

Deployment: `.github/workflows/foundry-agent-qa-test.yml` calls the single reusable
`.github/workflows/foundry-agent-container-reusable.yml` from `main`. It builds and
pushes to ACR, deploys an immutable image digest, waits for active status, optionally
promotes the endpoint and checks the actual running version. No source packaging
or remote source build is used. See [Docker deployment](FOUNDRY-CONTAINER-DEPLOYMENT.md)
for the caller and all environment settings.

The deployed probe does not invoke the model or write alerts. Before enabling
alert processing, configure the agent runtime's PostgreSQL settings, Entra database
role, schema, permissions and private network access. The Docker deployment currently
passes only the model setting; database-dependent alert processing is not yet
configured by this workflow. See the [agent README](../applications/foundry-hosted-alert-agent/README.md).

## Deployment order

Provision and review infrastructure, complete private DNS and application network connectivity, configure database authentication/schema/permissions, deploy the agent, configure Function hosting/authentication/settings, then deploy the Function. The workflows do not automatically trigger each other. A GitHub-hosted runner cannot directly reach private service endpoints without appropriate private network connectivity.