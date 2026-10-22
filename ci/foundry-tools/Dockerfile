# Deployment-only runtime. Build and push agent images in a separate build job.
# Refresh these digests together, then rebuild, test and scan before publishing.
ARG NODE_IMAGE=node:24-trixie-slim@sha256:43b9ba1142b8dcf33fa8f922ca1be85714adc444e0586c7cf7726daaeabc1bea
ARG PYTHON_IMAGE=python:3.13-slim-trixie@sha256:27b7c9d4f13ca20bb1170148f02095d50a5dfce1f7f2dabf5ca273727e43b7ea

FROM ${NODE_IMAGE} AS node_runtime
FROM ${PYTHON_IMAGE}

ARG AZURE_CLI_VERSION=2.91.0
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates git libstdc++6 \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip install --no-cache-dir "azure-cli==${AZURE_CLI_VERSION}" \
       'certifi==2026.10.19' 'urllib3==2.8.0' \
    && python -m pip check \
    && python -m pip uninstall -y pip \
    && python -c 'import ensurepip, pathlib, shutil; shutil.rmtree(pathlib.Path(ensurepip.__file__).parent)'

COPY --from=node_runtime /usr/local/bin/node /usr/local/bin/node

# All Python dependencies are installed and checked at build time. Deployment
# downloads the standalone script and uses Azure CLI; it needs no package installer.
RUN python --version \
    && az version --output none \
    && node --version \
    && git --version \
    && python -c 'import importlib.util, shutil; assert importlib.util.find_spec("pip") is None; assert importlib.util.find_spec("ensurepip") is None; assert shutil.which("docker") is None'

WORKDIR /work
ENTRYPOINT []
CMD ["bash"]
