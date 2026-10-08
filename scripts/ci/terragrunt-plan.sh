#!/usr/bin/env bash
set -euo pipefail
: "${ARM_CLIENT_ID:?}" "${ARM_TENANT_ID:?}" "${ARM_SUBSCRIPTION_ID:?}"
: "${TG_STATE_RESOURCE_GROUP:?}" "${TG_STATE_STORAGE_ACCOUNT:?}" "${TG_STATE_CONTAINER:?}" "${TG_STATE_KEY:?}"
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root/terragrunt/environments/poc"
terragrunt run --non-interactive -- init -input=false -lockfile=readonly
# Existing POC ownership must already be present in the combined state.
terragrunt run --non-interactive -- state pull |
  jq -e '[.resources[]? | select(.mode == "managed") | .instances[]?] | length > 0' > /dev/null || {
    echo "The combined POC state has no managed resources. Check TG_STATE_KEY before planning." >&2
    exit 1
  }
mkdir -p "$repo_root/plan-artifacts"
terragrunt run --non-interactive -- plan -input=false -lock-timeout=5m -out="$repo_root/plan-artifacts/tfplan"
terragrunt run --non-interactive -- show -json "$repo_root/plan-artifacts/tfplan" > "$repo_root/plan-artifacts/plan.json"
jq -e --arg subscription "$ARM_SUBSCRIPTION_ID" --arg tenant "$ARM_TENANT_ID" \
  '.configuration.provider_config.azurerm.expressions.subscription_id.constant_value == $subscription and .configuration.provider_config.azurerm.expressions.tenant_id.constant_value == $tenant' "$repo_root/plan-artifacts/plan.json" > /dev/null
python "$repo_root/scripts/ci/check-plan.py" < "$repo_root/plan-artifacts/plan.json"
