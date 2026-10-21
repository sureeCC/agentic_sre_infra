#!/usr/bin/env python3
"""Foundry hosted-agent deployment CLI, distributed as one standalone file.

Commands: deploy, verify, summary. Uses Python standard library and Azure CLI.
Authentication must already be established by the workflow's Azure login step.
No command builds an image or tests model inference/database connectivity.
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import re
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from http.client import IncompleteRead
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

LOGGER = logging.getLogger("foundry-agent")
TOKEN_TIMEOUT_SECONDS = 60
REQUEST_TIMEOUT_SECONDS = 120
PROVISIONING_TIMEOUT_SECONDS = 1200
POLL_INTERVAL_SECONDS = 10
READ_ATTEMPTS = 3
MAX_RETRY_WAIT_SECONDS = 300


class NoRedirect(HTTPRedirectHandler):
    """Do not forward authenticated requests to a redirect destination."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


urlopen = build_opener(NoRedirect()).open


def object_field(value, field):
    """Validate nested response objects without logging their contents."""
    result = value.get(field, {})
    if not isinstance(result, dict):
        raise RuntimeError(f"Malformed Foundry response: {field} must be an object")
    return result


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ValueError(f"Missing environment variable: {name}")
    return value


def remaining_seconds(deadline):
    """Fail before starting more work after the provisioning deadline."""
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("Provisioning deadline expired")
    return remaining


def request(url, method="GET", body=None, *, deadline=None):
    """Make one authenticated request; never log tokens or response bodies."""
    token = subprocess.check_output(
        ["az", "account", "get-access-token", "--resource", "https://ai.azure.com",
         "--query", "accessToken", "-o", "tsv"], text=True,
        stderr=subprocess.PIPE,
        timeout=min(TOKEN_TIMEOUT_SECONDS, remaining_seconds(deadline)) if deadline is not None else TOKEN_TIMEOUT_SECONDS,
    ).strip()
    if not token:
        raise RuntimeError("Azure CLI returned an empty access token")
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/merge-patch+json" if method == "PATCH" else "application/json"
    try:
        with urlopen(Request(url, data=None if body is None else json.dumps(body).encode(),
                             headers=headers, method=method),
                     timeout=min(REQUEST_TIMEOUT_SECONDS, remaining_seconds(deadline)) if deadline is not None else REQUEST_TIMEOUT_SECONDS) as response:
            data = response.read()
            result = json.loads(data) if data else {}
            if not isinstance(result, dict):
                raise ValueError("Foundry API response must be a JSON object")
            if deadline is not None:
                remaining_seconds(deadline)
            return result
    except HTTPError as error:
        LOGGER.debug("Foundry %s request returned HTTP %s", method, error.code)
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


def target():
    endpoint = required("FOUNDRY_PROJECT_ENDPOINT").rstrip("/")
    try:
        parsed = urlparse(endpoint)
        port = parsed.port
    except ValueError:
        raise ValueError("Invalid Foundry project endpoint") from None
    if (parsed.scheme != "https"
            or not re.fullmatch(r"[a-z0-9][a-z0-9-]*\.services\.ai\.azure\.com", parsed.hostname or "")
            or port not in (None, 443)
            or not re.fullmatch(r"/api/projects/[A-Za-z0-9_-]+", parsed.path)
            or parsed.query or parsed.fragment or parsed.username or parsed.password):
        raise ValueError("Expected an HTTPS Foundry project endpoint in Azure public cloud")
    name = required("FOUNDRY_AGENT_NAME")
    if not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?", name):
        raise ValueError("Invalid Foundry agent name")
    return endpoint, name


def retry_delay(error, fallback):
    """Honor Retry-After seconds or HTTP-date; ignore malformed values."""
    value = error.headers.get("Retry-After") if error.headers else None
    if value is None:
        return fallback
    if re.fullmatch(r"[0-9]+", value.strip()):
        # Avoid unbounded integer conversion for a malformed server header.
        digits = value.strip().lstrip("0") or "0"
        return int(digits) if len(digits) <= 6 else MAX_RETRY_WAIT_SECONDS + 1
    try:
        retry_at = parsedate_to_datetime(value)
        if retry_at.tzinfo is None:
            retry_at = retry_at.replace(tzinfo=timezone.utc)
        return max(0, (retry_at - datetime.now(timezone.utc)).total_seconds())
    except (ValueError, TypeError, OverflowError):
        return fallback


def wait_for_retry(delay, deadline=None):
    if delay > MAX_RETRY_WAIT_SECONDS:
        raise TimeoutError("Server retry delay exceeds the supported retry wait; try later")
    if deadline is not None and delay >= remaining_seconds(deadline):
        raise TimeoutError("Retry delay exceeds remaining provisioning time")
    time.sleep(delay)
    if deadline is not None:
        remaining_seconds(deadline)


def read_request(url, *, deadline=None):
    """Retry only reads; never repeat a potentially completed version creation."""
    for attempt in range(READ_ATTEMPTS):
        delay = 5 * (attempt + 1)
        try:
            if deadline is None:
                return request(url)
            remaining_seconds(deadline)
            result = request(url, deadline=deadline)
            remaining_seconds(deadline)
            return result
        except HTTPError as error:
            if error.code not in (408, 429, 500, 502, 503, 504) or attempt == READ_ATTEMPTS - 1:
                raise
            delay = retry_delay(error, delay)
        except (URLError, TimeoutError, IncompleteRead, ConnectionError):
            if attempt == READ_ATTEMPTS - 1:
                raise
        if deadline is not None:
            remaining_seconds(deadline)
        LOGGER.warning("Transient read failure; retry %s/%s", attempt + 2, READ_ATTEMPTS)
        wait_for_retry(delay, deadline)


def deploy_agent():
    """Create one version, wait until active, and set routing to always latest.

    POST/PATCH requests are never retried: a lost response can hide a successful
    write. Inspect Foundry before rerunning an interrupted deployment.
    """
    endpoint, name = target()
    payload = {"definition": definition()}
    agent_url = f"{endpoint}/agents/{name}"
    try:
        read_request(f"{agent_url}?api-version=v1")
    except HTTPError as error:
        if error.code != 404:
            raise
        result = request(f"{endpoint}/agents?api-version=v1", "POST", {"name": name, **payload})
    else:
        result = request(f"{agent_url}/versions?api-version=v1", "POST", payload)
    version = result.get("version")
    if not version:
        version = object_field(object_field(result, "versions"), "latest").get("version")
    if not version:
        raise RuntimeError("No version in deployment response; inspect Foundry before retrying")
    version = str(version)
    if not re.fullmatch(r"[0-9]+", version):
        raise RuntimeError("Invalid agent version in deployment response; inspect Foundry before retrying")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as outputs:
            outputs.write(f"agent_version={version}\n")
    LOGGER.info("Created agent version %s; waiting for active status", version)
    deadline = time.monotonic() + PROVISIONING_TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        result = read_request(f"{agent_url}/versions/{version}?api-version=v1", deadline=deadline)
        status = result.get("status")
        if status not in {"creating", "active", "failed", "deleting", "deleted"}:
            raise RuntimeError("Malformed Foundry response: missing or unsupported provisioning status")
        LOGGER.info("Provisioning status: %s", status)
        if status == "active":
            # Keep the stable endpoint following future versions; preserve protocols/auth.
            request(f"{agent_url}?api-version=v1", "PATCH", {
                "agent_endpoint": {"version_selector": {"version_selection_rules": [
                    {"type": "FixedRatio", "agent_version": "@latest", "traffic_percentage": 100}
                ]}}
            }, deadline=deadline)
            remaining_seconds(deadline)
            LOGGER.info("Deployment completed; endpoint configured to always use latest")
            return
        if status == "failed":
            raise RuntimeError("Foundry provisioning failed; inspect version diagnostics in Foundry")
        if status in {"deleting", "deleted"}:
            raise RuntimeError(f"Foundry version is {status}; deployment cannot complete")
        wait_for_retry(POLL_INTERVAL_SECONDS, deadline)
    raise TimeoutError("Agent did not become active within 20 minutes")



def deployed_version():
    endpoint, name = target()
    version = required("DEPLOYED_AGENT_VERSION")
    if not re.fullmatch(r"[0-9]+", version):
        raise ValueError("Invalid deployed agent version")
    info = read_request(f"{endpoint}/agents/{name}/versions/{version}?api-version=v1")
    if info.get("status") != "active":
        raise RuntimeError("Deployed version is not active")
    if object_field(object_field(info, "definition"), "container_configuration").get("image") != required("AGENT_IMAGE"):
        raise RuntimeError("Deployed version does not reference the expected image digest")
    return endpoint, name, version


def verify_agent():
    """Verify deployment readiness through the agent's stateless probe protocol."""
    endpoint, name, version = deployed_version()
    agent = read_request(f"{endpoint}/agents/{name}?api-version=v1")
    rules = object_field(object_field(agent, "agent_endpoint"), "version_selector").get("version_selection_rules", [])
    if not isinstance(rules, list) or any(not isinstance(rule, dict) for rule in rules):
        raise RuntimeError("Malformed Foundry response: version selection rules must be objects in an array")
    latest = str(object_field(object_field(agent, "versions"), "latest").get("version"))
    follows_latest = (not rules or (len(rules) == 1
                      and rules[0].get("type") == "FixedRatio"
                      and rules[0].get("agent_version") == "@latest"
                      and rules[0].get("traffic_percentage") == 100))
    if not follows_latest or latest != version:
        raise RuntimeError("Agent endpoint is not following the deployed latest version; probe was not sent")
    nonce = uuid.uuid4().hex
    expected = f"DEPLOYMENT_OK:{nonce}:{version}"
    # Retries are safe here: this reserved probe performs no model or tool calls.
    for attempt in range(3):
        try:
            result = request(
                f"{endpoint}/agents/{name}/endpoint/protocols/openai/responses?api-version=v1",
                "POST", {"input": f"__deployment_healthcheck__:{nonce}", "stream": False, "store": False},
            )
            break
        except HTTPError as error:
            if error.code not in (408, 424, 429, 500, 502, 503, 504) or attempt == 2:
                raise
            wait_for_retry(retry_delay(error, 10))
        except (URLError, TimeoutError, IncompleteRead, ConnectionError):
            if attempt == 2:
                raise
            time.sleep(10)
    output = result.get("output", [])
    if not isinstance(output, list) or any(not isinstance(item, dict) for item in output):
        raise RuntimeError("Malformed Foundry response: probe output must be an array of objects")
    text_parts = []
    for item in output:
        if item.get("type") != "message":
            continue
        contents = item.get("content", [])
        if not isinstance(contents, list) or any(not isinstance(part, dict) for part in contents):
            raise RuntimeError("Malformed Foundry response: probe content must be an array of objects")
        for part in contents:
            if part.get("type") == "output_text":
                if not isinstance(part.get("text"), str):
                    raise RuntimeError("Malformed Foundry response: probe text must be a string")
                text_parts.append(part["text"])
    text = "".join(text_parts)
    if result.get("status") != "completed" or text != expected:
        raise RuntimeError("Deployment probe did not return the expected nonce and deployed version")
    LOGGER.info("Verification passed: expected image, latest routing and running version %s", version)



def render_summary(env):
    def value(key):
        return str(env.get(key) or "Not reached").replace("\n", " ").replace("|", "\\|").replace("`", "")

    result = value("JOB_STATUS")
    lines = [f"## Foundry Docker deployment - {result}", "",
             f"Environment: **{value('DEPLOYMENT_ENVIRONMENT')}**", "",
             "| Deployment | Value |", "|---|---|",
             f"| CI tools image | `{value('CI_TOOLS_IMAGE')}` |",
             f"| Agent | `{value('FOUNDRY_AGENT_NAME')}` |",
             f"| Version | `{value('DEPLOYED_AGENT_VERSION')}` |",
             f"| Image tag | `{value('IMAGE_TAG')}` |",
             f"| Image digest reference | `{value('AGENT_IMAGE')}` |",
             f"| Project endpoint | {value('FOUNDRY_PROJECT_ENDPOINT')} |",
             f"| Source commit | `{value('GITHUB_SHA')}` |", ""]
    return "\n".join(lines)


def write_summary():
    """Write the GitHub summary, or stdout when invoked outside Actions."""
    content = render_summary(os.environ)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a", encoding="utf-8") as summary_file:
            summary_file.write(content)
        LOGGER.info("Pipeline summary written")
    else:
        print(content)


def main(argv=None):
    """Dispatch a command and return a nonzero exit code on failure."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("deploy", "verify", "summary"))
    args = parser.parse_args(argv)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)sZ %(levelname)s %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S",
    )
    logging.Formatter.converter = time.gmtime
    commands = {"deploy": deploy_agent, "verify": verify_agent, "summary": write_summary}
    try:
        LOGGER.info("Starting %s", args.command)
        commands[args.command]()
        LOGGER.info("Completed %s", args.command)
        return 0
    except HTTPError as error:
        LOGGER.error("%s failed: Foundry API HTTP %s; inspect Azure permissions or version diagnostics",
                     args.command, error.code)
    except subprocess.TimeoutExpired:
        LOGGER.error("%s failed: Azure CLI token acquisition timed out (maximum %s seconds, limited by remaining provisioning time)",
                     args.command, TOKEN_TIMEOUT_SECONDS)
    except subprocess.CalledProcessError:
        LOGGER.error("%s failed: Azure CLI could not obtain an access token; check Azure login",
                     args.command)
    except (json.JSONDecodeError, UnicodeError):
        LOGGER.error("%s failed: API or CLI returned invalid JSON or text encoding", args.command)
    except (TimeoutError, URLError, IncompleteRead, ConnectionError):
        LOGGER.error("%s failed: request or provisioning wait timed out, or network unavailable", args.command)
    except (ValueError, RuntimeError) as error:
        LOGGER.error("%s failed: %s", args.command, error)
    except OSError:
        LOGGER.error("%s failed: could not execute Azure CLI or access an output file", args.command)
    except Exception:
        LOGGER.error("%s failed: unexpected response or internal error; inspect the script and Foundry state",
                     args.command)
    except KeyboardInterrupt:
        LOGGER.error("%s interrupted", args.command)
        return 130
    if args.command == "deploy":
        LOGGER.error("A write may already have succeeded. Inspect Foundry before rerunning; no automatic rollback.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

