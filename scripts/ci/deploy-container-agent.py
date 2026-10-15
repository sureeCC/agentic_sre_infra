"""Deploy a digest-pinned ACR image to Foundry; never retry ambiguous writes."""
import json
import os
import re
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing environment variable: {name}")
    return value


def request(url, method="GET", body=None):
    token = subprocess.check_output(
        ["az", "account", "get-access-token", "--resource", "https://ai.azure.com",
         "--query", "accessToken", "-o", "tsv"], text=True,
    ).strip()
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    try:
        with urlopen(Request(url, data=None if body is None else json.dumps(body).encode(),
                             headers=headers, method=method), timeout=120) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except HTTPError as error:
        if error.code != 404:
            print(f"Foundry API HTTP {error.code}: {error.read().decode(errors='replace')}", flush=True)
        raise


def definition():
    image = required("AGENT_IMAGE")
    registry = required("ACR_LOGIN_SERVER")
    if not re.fullmatch(r"[a-z0-9]+\.azurecr\.io", registry):
        raise ValueError("Expected an Azure public-cloud ACR login server")
    if not re.fullmatch(re.escape(registry) + r"/[a-z0-9][a-z0-9._/-]*@sha256:[a-f0-9]{64}", image):
        raise ValueError("AGENT_IMAGE must reference the configured ACR by immutable sha256 digest")
    # Foundry injects FOUNDRY_PROJECT_ENDPOINT into hosted containers itself.
    return {
        "kind": "hosted",
        "protocol_versions": [{"protocol": "responses", "version": "2.0.0"}],
        "container_configuration": {"image": image},
        "cpu": required("AGENT_CPU"),
        "memory": required("AGENT_MEMORY"),
        "environment_variables": {
            "AZURE_AI_MODEL_DEPLOYMENT_NAME": required("AZURE_AI_MODEL_DEPLOYMENT_NAME"),
        },
    }


def main():
    endpoint = required("FOUNDRY_PROJECT_ENDPOINT").rstrip("/")
    parsed = urlparse(endpoint)
    if (parsed.scheme != "https" or not (parsed.hostname or "").endswith(".services.ai.azure.com")
            or not re.fullmatch(r"/api/projects/[^/]+", parsed.path)
            or parsed.query or parsed.fragment or parsed.username or parsed.password):
        raise ValueError("Expected an HTTPS Foundry project endpoint in Azure public cloud")
    name = required("FOUNDRY_AGENT_NAME")
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", name):
        raise ValueError("Invalid Foundry agent name")
    payload = {"definition": definition()}
    agent_url = f"{endpoint}/agents/{name}"
    try:
        request(f"{agent_url}?api-version=v1")
    except HTTPError as error:
        if error.code != 404:
            raise
        result = request(f"{endpoint}/agents?api-version=v1", "POST", {"name": name, **payload})
    else:
        result = request(f"{agent_url}/versions?api-version=v1", "POST", payload)
    version = result.get("version") or result.get("versions", {}).get("latest", {}).get("version")
    if not version:
        raise RuntimeError("No version in deployment response; inspect Foundry before retrying")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as outputs:
            outputs.write(f"agent_version={version}\n")
    print(f"Agent {name}, version {version}, image {required('AGENT_IMAGE')}", flush=True)
    deadline = time.monotonic() + 1200
    while time.monotonic() < deadline:
        result = request(f"{agent_url}/versions/{version}?api-version=v1")
        status = result.get("status")
        print(f"Status: {status}", flush=True)
        if status == "active":
            return
        if status == "failed":
            raise RuntimeError(f"Foundry provisioning failed: {result.get('error')}")
        time.sleep(10)
    raise TimeoutError("Agent did not become active within 20 minutes")


if __name__ == "__main__":
    main()
