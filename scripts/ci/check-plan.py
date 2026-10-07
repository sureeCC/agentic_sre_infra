"""Summarize resource actions without disclosing plan values; reject deletes."""
import collections
import json
import os
import sys

plan = json.load(sys.stdin)
counts = collections.Counter()
deletes = []
for resource in plan.get("resource_changes", []):
    actions = resource["change"]["actions"]
    counts["/".join(actions)] += 1
    if "delete" in actions:
        deletes.append(resource["address"])
summary = "### Terraform resource actions\n\n" + "\n".join(
    f"- {action}: {count}" for action, count in sorted(counts.items())
) + "\n"
print(summary)
with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
    output.write(summary)
if deletes and os.environ.get("ALLOW_DELETIONS") != "true":
    sys.exit("Deletes/replacements blocked: " + ", ".join(deletes))
