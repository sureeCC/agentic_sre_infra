# Containerized Foundry CI

There are two separate images:

- **CI tools image:** `suresh3796/vm-foundry-image`, pulled before the pipeline job.
  It contains Python 3.13, Azure CLI 2.91.0, Docker CLI/Buildx, Node 24, Bash,
  Git, curl, jq, CA certificates and SSH client tools.
- **Agent image:** built from `applications/foundry-hosted-alert-agent/Dockerfile`,
  pushed to ACR, and deployed to Foundry by digest.

No Python setup action or tool/package installation runs on the VM during the
deployment job. Checkout, Azure login, tests and deployment scripts execute inside
the CI job container. Application dependencies are installed only while building
the separate agent image.

## Docker Hub scenario

1. Run **Build Foundry CI tools image** from `main`. With `push_to_dockerhub=false`,
   it builds and checks the image without publishing. With publishing enabled,
   it pushes a unique commit/run/attempt tag to `suresh3796/vm-foundry-image`.
2. Publishing uses repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
   The PAT must permit pushing to that Docker Hub repository. Credentials never
   enter either Dockerfile, build arguments or image layers.
3. Set repository variable `CI_RUNNER_IMAGE` to the published digest reference
   shown in the image-build summary. The CI image must exist before a deployment
   job starts; a job cannot build the container it is already running inside.
4. The QA caller passes `image_name: ${{ vars.CI_RUNNER_IMAGE }}` to the reusable
   workflow. PR validation also uses that image.
5. Run the QA deployment workflow. Its validation step checks `/.dockerenv` and
   tool versions, then uses the existing Azure OIDC credentials, Docker build,
   ACR push, Foundry deployment, post-deployment check and summary.

The bootstrap image build also executes in a Docker job container (`docker:28-cli`).
It uses shell-only checkout/build/login commands, avoiding JavaScript actions in
that Alpine bootstrap image. The resulting Debian-based CI image supports the
JavaScript actions used by the deployment job. No Azure or Docker Hub login is
baked into it.

## Docker access and the organization VM

The CI image has the Docker **client**, not a running Docker daemon. The job mounts
`/var/run/docker.sock` from the Linux VM. Build/push commands run in the job
container and send requests to the VM's Docker Engine. Agent import checks start
a sibling container through that same engine. This is socket sharing, not Docker
in Docker, and needs no privileged DinD service.

The VM needs Docker Engine and a registered GitHub Actions runner. The runner
agent orchestrates the job; it is separate from this tools image. If policy also
requires the runner agent itself to be containerized, run that agent in its own
runner container with the organization's supported workspace/socket mounts.
For this recreation `ubuntu-24.04` provides the VM/runner; replace `runner_name`
with the organization's Linux runner label later.

Access to the Docker socket grants control over the VM's Docker daemon. Use this
only for trusted workflows on dedicated/ephemeral runners. A policy that forbids
socket sharing needs a separate authenticated build service instead.

## Replace Docker Hub with JFrog

Publish the **same CI image** to the organization's Docker repository in JFrog.
Set `CI_RUNNER_IMAGE` to its JFrog digest reference and configure pull credentials:

- `CI_REGISTRY_USERNAME`: JFrog service account.
- `CI_REGISTRY_PASSWORD`: scoped JFrog pull token.

Those credentials are used by `container.credentials` before any job step runs.
Step-level `docker login` happens too late to pull the job image. Configure these
as repository/organization secrets available to the caller; do not expose private
registry credentials to untrusted fork pull requests.

Keep agent-image destination and Azure credentials independent: the current
agent image still goes to ACR using managed-identity OIDC. Changing the tools-image
registry does not change the Foundry deployment target.

The Dockerfile pins Azure CLI; source Python/Node/Docker tags and transitive
dependencies are resolved at tools-image build time. Jobs use a published digest.
For organization releases, pin base-image digests and maintain a reviewed tools
dependency lock in addition to scanning/updating the tools image.

References: [GitHub job containers](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/run-jobs-in-a-container),
[self-hosted Linux runners](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).
