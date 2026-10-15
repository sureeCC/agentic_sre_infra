# Foundry Docker deployment

The QA caller `.github/workflows/foundry-agent-qa-test.yml` invokes
`foundry-agent-container-reusable.yml`. Run it manually from GitHub Actions.
It uses the same QA Environment, OIDC managed identity and production approval
pattern as the source-upload workflow.

The workflow builds `applications/foundry-hosted-alert-agent/Dockerfile` for
`linux/amd64`. The image runs Python 3.13 as an unprivileged user and starts the
Responses server on port 8088. Only `main.py` and `requirements.txt` are copied
into the image. No credentials are provided as build arguments or image layers.

Before pushing, the job starts the image and polls `/readiness`. This checks
server startup without model inference or a PostgreSQL connection. It then
pushes a unique commit/run/attempt tag to ACR and deploys the resulting immutable
`registry/repository@sha256:...` reference. Foundry receives JSON containing
`container_configuration`, with no source ZIP or `code_configuration`.

## Configuration

QA Environment secrets: `CLIENT_ID`, `TENANT_ID`, `SUBSCRIPTION`.
The reusable workflow also accepts matching Environment variables as a fallback.

Environment variables:

- `ACR_NAME`: registry resource name.
- `AGENT_IMAGE_REPOSITORY`: defaults to `sre-alert-postgres-hosted`.
- `FOUNDRY_PROJECT_ENDPOINT`, `FOUNDRY_AGENT_NAME`.
- `AZURE_AI_MODEL_DEPLOYMENT_NAME`, `AGENT_CPU`, `AGENT_MEMORY`.
- `POSTGRES_HOST`, `POSTGRES_DATABASE`, `POSTGRES_AAD_USER`: non-secret runtime
  settings retained for the application; the deployment test does not use them.

The pipeline identity needs registry-scoped `AcrPush` and project-scoped
`Foundry Project Manager`. The Foundry project identity needs registry-scoped
`AcrPull` for QA's legacy registry permission mode. An ABAC-enabled registry uses
the corresponding Repository Writer/Reader roles instead. Registry ARM-token
authentication must be enabled.

Standard GitHub-hosted runners require reachable Foundry and ACR endpoints.
Public endpoints still require Entra authentication; leave ACR admin credentials
and anonymous pulls disabled. Private endpoints require suitable runner and
Foundry network connectivity. QA's public-access test exceptions are Azure-side
changes; the current Terragrunt inputs still disable public access and will
restore it on a later apply.

The optional `image_name` input is the **job execution container**, not the agent
image. Normally leave it empty on `ubuntu-24.04`; a supplied job container must
have Python 3.13, Azure CLI, Docker CLI and access to a working Docker daemon.

The older source-code reusable workflow and its packaging helper remain
available. The Docker workflow uses `deploy-container-agent.py` instead.

Dependencies and the base-image tag are currently resolved during the build.
The pushed agent image is deployed by digest, but reproducible production builds
also require a dependency lock and a pinned base-image digest.

Reference: https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/deploy-hosted-agent
