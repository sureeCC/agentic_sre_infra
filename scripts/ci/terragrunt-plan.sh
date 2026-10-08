#!/usr/bin/env bash
set -euo pipefail
: "${ARM_CLIENT_ID:?}" "${ARM_TENANT_ID:?}" "${ARM_SUBSCRIPTION_ID:?}"
: "${TG_STATE_RESOURCE_GROUP:?}" "${TG_STATE_STORAGE_ACCOUNT:?}" "${TG_STATE_CONTAINER:?}"
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root/terragrunt/environments/poc"
units=(resource-group app-registrations event-hubs foundry postgresql function-app)
# Require migrated ownership; plans never use validation placeholders.
for unit in "${units[@]}"; do
  terragrunt run --non-interactive --working-dir "$PWD/$unit" -- init -input=false -lockfile=readonly
  terragrunt run --non-interactive --working-dir "$PWD/$unit" -- state pull |
    jq -e '[.resources[]? | select(.mode == "managed") | .instances[]?] | length > 0' > /dev/null || {
      echo "State migration is incomplete for $unit. Import/migrate its managed resources before planning." >&2
      exit 1
    }
done
terragrunt run --all --non-interactive --out-dir "$repo_root/plan-artifacts/binary" \
  --json-out-dir "$repo_root/plan-artifacts/json" -- plan -input=false -lock-timeout=5m
count=0
while IFS= read -r -d '' plan; do
  jq -e --arg subscription "$ARM_SUBSCRIPTION_ID" --arg tenant "$ARM_TENANT_ID" \
    '.configuration.provider_config.azurerm.expressions.subscription_id.constant_value == $subscription and .configuration.provider_config.azurerm.expressions.tenant_id.constant_value == $tenant' "$plan" > /dev/null
  python "$repo_root/scripts/ci/check-plan.py" < "$plan"
  count=$((count + 1))
done < <(find "$repo_root/plan-artifacts/json" -type f -name '*.json' -print0)
test "$count" -eq 6
