#!/usr/bin/env bash
set -euo pipefail
case "${ACTION:-}" in plan|apply) ;; *) echo 'ACTION must be plan or apply' >&2; exit 1;; esac
case "${UNIT:-}" in
  all) units=(managed-identity event-hub acr key-vault database foundry) ;;
  managed-identity|event-hub|acr|key-vault|database|foundry) units=("$UNIT") ;;
  *) echo 'Unknown infrastructure unit' >&2; exit 1 ;;
esac
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '### Infrastructure %s (%s)\n\n| Unit | Result |\n|---|---|\n' "$ACTION" "${BRANCH_NAME:-}" >> "$GITHUB_STEP_SUMMARY"
fi
for unit in "${units[@]}"; do
  echo "::group::$unit: validate and $ACTION"
  # Apply each dependency before planning its dependants. Foundry reads identity state.
  if (
    cd "$repo_root/live/$unit" || exit $?
    terragrunt run -- init -input=false || exit $?
    terragrunt run -- validate || exit $?
    terragrunt run -- plan -input=false -out=tfplan || exit $?
    if [[ "$ACTION" == apply ]]; then
      terragrunt run -- apply -input=false tfplan || exit $?
    fi
  ); then
    [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || printf '| %s | %s succeeded |\n' "$unit" "$ACTION" >> "$GITHUB_STEP_SUMMARY"
  else
    echo "::endgroup::"
    [[ -z "${GITHUB_STEP_SUMMARY:-}" ]] || printf '| %s | Failed; remaining units stopped |\n' "$unit" >> "$GITHUB_STEP_SUMMARY"
    exit 1
  fi
  echo '::endgroup::'
done
