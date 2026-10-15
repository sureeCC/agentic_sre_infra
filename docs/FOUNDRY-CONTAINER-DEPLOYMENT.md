# Foundry Docker deployment

The QA caller `.github/workflows/foundry-agent-qa-test.yml` invokes
`foundry-agent-container-reusable.yml`. Run it manually from GitHub Actions.
It deploys from the main trunk using the QA Environment and OIDC managed identity.
There is no separate approval job; build, push, deploy and verification run consecutively.

The workflow builds `applications/foundry-hosted-alert-agent/Dockerfile` for
`linux/amd64`. The image runs Python 3.13 as an unprivileged user and starts the
Responses server on port 8088. Only `main.py` and `requirements.txt` are copied
into the image. No credentials are provided as build arguments or image layers.

The workflow pushes a unique commit/run/attempt tag to ACR and deploys the resulting
immutable `registry/repository@sha256:...` reference. There is no local container
readiness step. Foundry receives JSON containing `container_configuration`,
with no source ZIP or `code_configuration`.

After Foundry reports `active`, the workflow checks the deployed image and endpoint
routing, then sends an authenticated, stateless probe through Foundry's Responses
endpoint. Agent middleware echoes the probe nonce and actual running version
without calling the model or `store_alert`. A wrong image, stale route, unexpected
response or failed request fails the job. Only transient errors on this
side-effect-free probe are retried, at most three times.

The QA caller explicitly sets `promote_endpoint: true` to route 100% of endpoint
traffic to the deployed version before probing it. The reusable input defaults
to false: callers with protected or split production routing must handle
promotion deliberately. Without promotion the check fails before invoking an
endpoint that routes to an older/different version.

An `always()` summary records environment, commit, image tag/digest, deployed
version and every stage's outcome, including skipped stages after a failure.
The deployed probe does not test inference or PostgreSQL connectivity.

## Configuration

QA Environment secrets: `CLIENT_ID`, `TENANT_ID`, `SUBSCRIPTION`.
The reusable workflow also accepts matching Environment variables as a fallback.

Environment variables:

- `ACR_NAME`: registry resource name.
- `AGENT_IMAGE_REPOSITORY`: defaults to `sre-alert-postgres-hosted`.
- `FOUNDRY_PROJECT_ENDPOINT`, `FOUNDRY_AGENT_NAME`.
- `AZURE_AI_MODEL_DEPLOYMENT_NAME`, `AGENT_CPU`, `AGENT_MEMORY`.
PostgreSQL settings are neither required nor included in the container deployment
definition. Configure database access separately before enabling the alert-storage
application flow.

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

Both reusable agent workflows deploy only when the caller ref is `refs/heads/main`.
Environment names select configuration, not Git branches. GitHub Environment
protection rules, if configured later, still apply to the deployment job.
