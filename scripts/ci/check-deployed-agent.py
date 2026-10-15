"""Check the deployed version and call its stateless deployment probe via Foundry."""
import importlib.util
import argparse
from pathlib import Path
import time
from urllib.error import HTTPError, URLError
import uuid

spec = importlib.util.spec_from_file_location("container_deployment", Path(__file__).with_name("deploy-container-agent.py"))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


def deployed_version():
    endpoint = deploy.required("FOUNDRY_PROJECT_ENDPOINT").rstrip("/")
    name = deploy.required("FOUNDRY_AGENT_NAME")
    version = deploy.required("DEPLOYED_AGENT_VERSION")
    info = deploy.request(f"{endpoint}/agents/{name}/versions/{version}?api-version=v1")
    if info.get("status") != "active":
        raise RuntimeError("Deployed version is not active")
    if info.get("definition", {}).get("container_configuration", {}).get("image") != deploy.required("AGENT_IMAGE"):
        raise RuntimeError("Deployed version does not reference the expected image digest")
    return endpoint, name, version


def promote():
    endpoint, name, version = deployed_version()
    deploy.request(f"{endpoint}/agents/{name}?api-version=v1", "PATCH", {
        "agent_endpoint": {
            "version_selector": {"version_selection_rules": [
                {"type": "FixedRatio", "agent_version": version, "traffic_percentage": 100}]},
            "protocol_configuration": {"responses": {}},
        },
    })
    print(f"Agent endpoint promoted to version {version} (100% traffic)")


def check():
    endpoint, name, version = deployed_version()
    agent = deploy.request(f"{endpoint}/agents/{name}?api-version=v1")
    rules = ((agent.get("agent_endpoint") or {}).get("version_selector") or {}).get("version_selection_rules", [])
    if rules:
        correct_route = (len(rules) == 1 and str(rules[0].get("agent_version")) == version
                         and rules[0].get("traffic_percentage") == 100)
    else:
        correct_route = str(agent.get("versions", {}).get("latest", {}).get("version")) == version
    if not correct_route:
        raise RuntimeError("Agent endpoint is not routed exclusively to the deployed version; probe was not sent")
    nonce = uuid.uuid4().hex
    expected = f"DEPLOYMENT_OK:{nonce}:{version}"
    # Retries are safe here: this reserved probe performs no model or tool calls.
    for attempt in range(3):
        try:
            result = deploy.request(
                f"{endpoint}/agents/{name}/endpoint/protocols/openai/responses?api-version=v1",
                "POST", {"input": f"__deployment_healthcheck__:{nonce}", "stream": False, "store": False},
            )
            break
        except HTTPError as error:
            if error.code not in (408, 424, 429, 500, 502, 503, 504) or attempt == 2:
                raise
            time.sleep(10)
        except (URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(10)
    text = "".join(
        content.get("text", "")
        for item in result.get("output", []) if item.get("type") == "message"
        for content in item.get("content", []) if content.get("type") == "output_text"
    )
    if result.get("status") != "completed" or text != expected:
        raise RuntimeError("Deployment probe did not return the expected nonce and deployed version")
    print(f"Post-deployment check passed: Foundry served version {version} from the expected image. No inference or database calls.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--promote", action="store_true", help="Explicitly route 100%% endpoint traffic to the deployed version")
    args = parser.parse_args()
    promote() if args.promote else check()
