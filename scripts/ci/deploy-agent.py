"""Deploy/version a Foundry source-code agent and wait for active status.

Uses the documented v1 multipart API and Azure CLI's OIDC-backed session.
Mutating POSTs are deliberately not retried after ambiguous network failures.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import uuid


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing environment variable: {name}")
    return value


def request(url, method="GET", body=None, headers=None):
    token = subprocess.check_output(
        ["az", "account", "get-access-token", "--resource", "https://ai.azure.com",
         "--query", "accessToken", "-o", "tsv"], text=True,
    ).strip()
    request_headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    request_headers.update(headers or {})
    with urlopen(Request(url, data=body, headers=request_headers, method=method), timeout=120) as response:
        return json.load(response)


def main():
    endpoint = required("FOUNDRY_PROJECT_ENDPOINT").rstrip("/")
    parsed = urlparse(endpoint)
    if (parsed.scheme != "https" or not (parsed.hostname or "").endswith(".services.ai.azure.com")
            or not parsed.path.startswith("/api/projects/") or parsed.query or parsed.fragment):
        raise ValueError("Expected an HTTPS Foundry project endpoint in Azure public cloud")
    name = required("FOUNDRY_AGENT_NAME")
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", name):
        raise ValueError("Invalid Foundry agent name")
    metadata = json.loads(Path("applications/foundry-hosted-alert-agent/metadata.json").read_text())
    metadata["definition"]["environment_variables"] = {
        key: required(key) for key in (
            "FOUNDRY_PROJECT_ENDPOINT", "AZURE_AI_MODEL_DEPLOYMENT_NAME",
            "POSTGRES_HOST", "POSTGRES_DATABASE", "POSTGRES_AAD_USER",
        )
    }
    metadata["definition"]["cpu"] = required("AGENT_CPU")
    metadata["definition"]["memory"] = required("AGENT_MEMORY")
    code = Path("dist/agent.zip").read_bytes()
    digest = hashlib.sha256(code).hexdigest()
    boundary = uuid.uuid4().hex
    body = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
        'Content-Type: application/json\r\n\r\n'
    ).encode() + json.dumps(metadata).encode() + (
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="code"; filename="agent.zip"\r\n'
        'Content-Type: application/zip\r\n\r\n'
    ).encode() + code + f"\r\n--{boundary}--\r\n".encode()
    headers = {"Content-Type": f"multipart/form-data; boundary={boundary}", "x-ms-code-zip-sha256": digest}
    agent_url = f"{endpoint}/agents/{name}"
    try:
        request(f"{agent_url}?api-version=v1")
    except HTTPError as error:
        if error.code != 404:
            raise
        headers["x-ms-agent-name"] = name
        result = request(f"{endpoint}/agents?api-version=v1", "POST", body, headers)
    else:
        result = request(f"{agent_url}/versions?api-version=v1", "POST", body, headers)
    version = result.get("version") or result.get("versions", {}).get("latest", {}).get("version")
    if not version:
        raise RuntimeError("Deployment response did not contain a version; inspect Foundry before retrying")
    print(f"Agent {name}, version {version}, source SHA256 {digest}", flush=True)
    deadline = time.monotonic() + 1200
    while time.monotonic() < deadline:
        result = request(f"{agent_url}/versions/{version}?api-version=v1")
        status = result.get("status")
        print(f"Status: {status}", flush=True)
        if status == "active":
            with open(required("GITHUB_STEP_SUMMARY"), "a", encoding="utf-8") as summary:
                summary.write(f"### Foundry deployment\n\nAgent: `{name}`\n\nVersion: `{version}`\n\nSource SHA256: `{digest}`\n")
            return
        if status == "failed":
            raise RuntimeError(f"Foundry provisioning failed: {result.get('error')}")
        time.sleep(10)
    raise TimeoutError("Agent did not become active within 20 minutes")


if __name__ == "__main__":
    main()
