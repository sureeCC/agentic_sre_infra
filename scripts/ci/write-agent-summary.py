"""Write a deployment summary even when an earlier workflow step fails."""
import json
import os


STAGES = (
    ("validate", "Configuration and offline tests"),
    ("login", "Azure OIDC login"),
    ("registry", "ACR login"),
    ("build", "Docker build"),
    ("push", "ACR push"),
    ("deploy", "Foundry deployment / active status"),
    ("route", "Endpoint promotion (explicit opt-in)"),
    ("post_check", "Deployed endpoint / version check"),
    ("registry_logout", "Registry logout"),
)


def render(env):
    def value(key):
        return str(env.get(key) or "Not reached").replace("\n", " ").replace("|", "\\|").replace("`", "")

    steps = json.loads(env.get("STAGE_RESULTS") or "{}")
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
             f"| Source commit | `{value('GITHUB_SHA')}` |", "",
             "| Pipeline stage | Result |", "|---|---|"]
    for stage, title in STAGES:
        lines.append(f"| {title} | {steps.get(stage, {}).get('outcome', 'not reached')} |")
    lines.extend(["", "The deployed check validates authenticated Foundry routing, the expected image, "
                  "and a nonce echoed by the expected running agent version.", "",
                  "**Model inference and PostgreSQL connectivity are not tested.**", ""])
    return "\n".join(lines)


if __name__ == "__main__":
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(render(os.environ))
