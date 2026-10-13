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
        name="ai-${APP,,}-${BRANCH_NAME}-${REGION}-${INSTANCE}-${suffix:0:6}"
        name="${name,,}"
        id="/subscriptions/$ARM_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.CognitiveServices/accounts/$name"
        az resource show --ids "$id" --subscription "$ARM_SUBSCRIPTION_ID" --query id -o tsv >/dev/null || exit $?
        addresses=$(terragrunt run -- state list) || exit $?
        if ! grep -Fxq 'azurerm_cognitive_account.foundry' <<< "$addresses"; then
          terragrunt run -- import -input=false azurerm_cognitive_account.foundry "$id" || exit $?
        else
          echo 'Foundry account is already managed; import skipped.'
        fi ;;
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
