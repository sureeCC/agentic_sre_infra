ARG DOCKER_CLI_IMAGE=docker:28-cli
ARG NODE_IMAGE=node:24-bookworm-slim
ARG PYTHON_IMAGE=python:3.13-slim-bookworm

FROM ${DOCKER_CLI_IMAGE} AS docker_cli
FROM ${NODE_IMAGE} AS node_runtime
FROM ${PYTHON_IMAGE}

ARG AZURE_CLI_VERSION=2.91.0
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates curl git jq libstdc++6 openssh-client unzip \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip install --no-cache-dir "azure-cli==${AZURE_CLI_VERSION}" \
    && python -m pip check

COPY --from=docker_cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker_cli /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node

# CI job containers need access to the VM's Docker socket. No Docker daemon is
# installed or started in this image. Only trusted workflows should use it.
RUN python --version \
    && az version --output none \
    && docker --version \
    && docker buildx version \
    && node --version \
    && git --version

WORKDIR /work
ENTRYPOINT []
CMD ["bash"]
