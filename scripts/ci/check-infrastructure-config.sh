#!/usr/bin/env bash
set -euo pipefail
required=(ARM_SUBSCRIPTION_ID ARM_TENANT_ID ARM_CLIENT_ID LOCATION REGION INSTANCE RESOURCE_GROUP_NAME VNET_NAME VNET_RESOURCE_GROUP_NAME PVE_SUBNET_NAME SVC_SUBNET_NAME POSTGRES_DNS_ZONE_NAME POSTGRES_DNS_RESOURCE_GROUP MODEL_NAME MODEL_VERSION ACR_NAME FOUNDRY_NAME FOUNDRY_PROJECT_NAME EVENTHUB_NAMESPACE_NAME APP OWNER PROVISIONED_TIME STATE_RESOURCE_GROUP STATE_STORAGE_ACCOUNT STATE_CONTAINER MODULE_REF)
missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if (( ${#missing[@]} )); then
  printf 'Missing configuration variable: %s\n' "${missing[@]}" >&2
  exit 1
fi
[[ "$MODULE_REF" =~ ^[0-9a-f]{40}$ ]] || { echo 'MODULE_REF must be a full module commit SHA.' >&2; exit 1; }
if [[ "${UNIT:-}" == database ]]; then
  [[ -n "${POSTGRES_ADMIN_PASSWORD:-}" ]] || { echo 'POSTGRES_ADMIN_PASSWORD secret is required for database.' >&2; exit 1; }
fi
