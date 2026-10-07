#!/usr/bin/env bash
set -euo pipefail
: "${ARM_CLIENT_ID:?}" "${ARM_TENANT_ID:?}" "${ARM_SUBSCRIPTION_ID:?}"
: "${TF_STATE_RESOURCE_GROUP:?}" "${TF_STATE_STORAGE_ACCOUNT:?}" "${TF_STATE_CONTAINER:?}" "${TF_STATE_KEY:?}"
terraform init -input=false -lockfile=readonly \
  -backend-config="resource_group_name=$TF_STATE_RESOURCE_GROUP" \
  -backend-config="storage_account_name=$TF_STATE_STORAGE_ACCOUNT" \
  -backend-config="container_name=$TF_STATE_CONTAINER" \
  -backend-config="key=$TF_STATE_KEY" \
  -backend-config="use_azuread_auth=true" \
  -backend-config="use_oidc=true"
