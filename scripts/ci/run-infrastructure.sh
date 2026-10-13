#!/usr/bin/env bash
set -euo pipefail
stage="${1:?Specify validate, plan or apply}"
case "$stage" in validate|plan|apply|import) ;; *) echo 'Unknown stage' >&2; exit 1;; esac
case "${ACTION:-}" in plan|apply|destroy|import) ;; *) echo 'Unknown action' >&2; exit 1;; esac
[[ "$ACTION" != import || "$UNIT" == foundry ]] || { echo 'Import supports only UNIT=foundry' >&2; exit 1; }
[[ "$stage" != import || "$ACTION" == import ]] || { echo 'Import requires ACTION=import' >&2; exit 1; }
[[ "$stage" != apply || "$ACTION" == apply || "$ACTION" == destroy ]] || { echo 'This action cannot apply' >&2; exit 1; }
case "${UNIT:-}" in
  all)
    units=(managed-identity event-hub acr key-vault database foundry)
    if [[ "$ACTION" == destroy ]]; then
      units=(foundry database key-vault acr event-hub managed-identity)
    fi ;;
  managed-identity|event-hub|acr|key-vault|database|foundry) units=("$UNIT") ;;
  *) echo 'Unknown infrastructure unit' >&2; exit 1 ;;
esac
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
plan_dir="${RUNNER_TEMP:?}/infrastructure-plans"
mkdir -p "$plan_dir"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '\n### %s stage — %s (%s)\n\n' "$stage" "$ACTION" "${BRANCH_NAME:-}" >> "$GITHUB_STEP_SUMMARY"
fi
for unit in "${units[@]}"; do
  echo "::group::$unit: $stage ($ACTION)"
  plan="$plan_dir/$unit.tfplan"
  changes="$plan_dir/$unit.changes.json"
  if (
    cd "$repo_root/live/$unit" || exit $?
    case "$stage" in
      import)
        # Import the exact recovered account; never infer or purge other resources.
        suffix="${ARM_SUBSCRIPTION_ID//-/}"
        name="ai-${APP,,}-${BRANCH_NAME}-${REGION}-${FOUNDRY_INSTANCE:-$INSTANCE}-${suffix:0:6}"
        name="${name,,}"
        id="/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.CognitiveServices/accounts/$name"
        az resource show --ids "$id" --subscription "$ARM_SUBSCRIPTION_ID" --query id -o tsv >/dev/null || exit $?
        addresses=$(terragrunt run -- state list) || exit $?
        project_name="proj-${APP,,}-${BRANCH_NAME}-${REGION}-${FOUNDRY_INSTANCE:-$INSTANCE}"
        if [[ -n "${FOUNDRY_REPLACEMENT_FROM_ID:-}" ]]; then
          # Explicit replacement only: retain the retired Azure account and
          # snapshot remote state before changing ownership. Never purge.
          prefix="/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.CognitiveServices/accounts/"
          [[ "$FOUNDRY_REPLACEMENT_FROM_ID" == "$prefix"* && "$FOUNDRY_REPLACEMENT_FROM_ID" != "$id" ]] || exit 1
          test "$(az resource show --ids "$id" --subscription "$ARM_SUBSCRIPTION_ID" --query properties.provisioningState -o tsv)" = Succeeded || exit $?
          test "$(az rest --method get --url "https://management.azure.com$id/projects/$project_name?api-version=2026-09-01" --query properties.provisioningState -o tsv)" = Succeeded || exit $?
          backup="$plan_dir/foundry-before-import.tfstate"
          terragrunt run -- state pull > "$backup" || exit $?
          current_id=$(node -e 'const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(s.resources.find(r=>r.type==="azurerm_cognitive_account"&&r.name==="foundry")?.instances[0]?.attributes.id||"")' "$backup") || exit $?
          [[ "${current_id,,}" == "${FOUNDRY_REPLACEMENT_FROM_ID,,}" ]] || { echo 'Retired account ID does not match state; refusing replacement.' >&2; exit 1; }
          az storage blob snapshot --auth-mode login --account-name "$STATE_STORAGE_ACCOUNT" --container-name "$STATE_CONTAINER" --name "${GITHUB_REPOSITORY##*/}/foundry/$BRANCH_NAME/terraform.tfstate" --subscription "$ARM_SUBSCRIPTION_ID" -o none || exit $?
          terragrunt run -- state rm azurerm_cognitive_account.foundry || exit $?
          if grep -Fxq 'azurerm_cognitive_account_project.project["imo"]' <<< "$addresses"; then
            terragrunt run -- state rm 'azurerm_cognitive_account_project.project["imo"]' || exit $?
          fi
          addresses=$(terragrunt run -- state list) || exit $?
        fi
        if ! grep -Fxq 'azurerm_cognitive_account.foundry' <<< "$addresses"; then
          terragrunt run -- import -input=false azurerm_cognitive_account.foundry "$id" || exit $?
        else
          echo 'Foundry account is already managed; import skipped.'
        fi
        if [[ -n "${FOUNDRY_REPLACEMENT_FROM_ID:-}" ]]; then
          terragrunt run -- import -input=false 'azurerm_cognitive_account_project.project["imo"]' "$id/projects/$project_name" || exit $?
        fi
        # Cancellation may leave completed DNS links outside the last saved
        # state. Import only the exact configured links to our configured VNet.
        for zone in privatelink.cognitiveservices.azure.com privatelink.openai.azure.com privatelink.services.ai.azure.com; do
          address="azurerm_private_dns_zone_virtual_network_link.service[\"$zone\"]"
          if ! grep -Fxq "$address" <<< "$addresses"; then
            link="link-${BRANCH_NAME}-${REGION}-${INSTANCE}"
            link_id="/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/privateDnsZones/$zone/virtualNetworkLinks/$link"
            if actual_vnet=$(az resource show --ids "$link_id" --subscription "$ARM_SUBSCRIPTION_ID" --query properties.virtualNetwork.id -o tsv 2>/dev/null); then
              expected_vnet="/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$VNET_RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$VNET_NAME"
              [[ "${actual_vnet,,}" == "${expected_vnet,,}" ]] || { echo 'Existing DNS link points to another VNet; refusing import.' >&2; exit 1; }
              terragrunt run -- import -input=false "$address" "$link_id" || exit $?
            fi
          fi
        done ;;
      validate)
        terragrunt run -- init -input=false || exit $?
        terragrunt run -- validate || exit $? ;;
      plan)
        flags=()
        [[ "$ACTION" != destroy ]] || flags+=(-destroy)
        terragrunt run -- plan -input=false "${flags[@]}" -out="$plan" || exit $?
        # Source downloads also contain other modules' lock files. Only the
        # executed module has an initialized .terraform directory.
        mapfile -t cache_dirs < <(find .terragrunt-cache -type d -name .terraform -prune -printf '%h\n')
        [[ ${#cache_dirs[@]} -eq 1 ]] || { echo 'Expected exactly one initialized Terraform cache' >&2; exit 1; }
        cache_dir="${cache_dirs[0]}"
        terraform -chdir="$cache_dir" show -json "$plan" |
          node "$repo_root/scripts/ci/infrastructure-summary.cjs" capture "$changes" || exit $?
        node "$repo_root/scripts/ci/infrastructure-summary.cjs" report "$changes" "$unit" plan || exit $? ;;
      apply)
        test -s "$plan" && test -s "$changes" || exit 1
        if terragrunt run -- apply -input=false "$plan"; then
          node "$repo_root/scripts/ci/infrastructure-summary.cjs" report "$changes" "$unit" completed || exit $?
        else
          rc=$?
          node "$repo_root/scripts/ci/infrastructure-summary.cjs" report "$changes" "$unit" failed
          exit "$rc"
        fi ;;
    esac
  ); then
    [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || printf '\n**%s: %s succeeded.**\n\n' "$unit" "$stage" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "::endgroup::"
    [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || printf '\n**%s: %s failed. Remaining units/stages stopped.**\n\n' "$unit" "$stage" >> "$GITHUB_STEP_SUMMARY"
    exit 1
  fi
  echo '::endgroup::'
done
