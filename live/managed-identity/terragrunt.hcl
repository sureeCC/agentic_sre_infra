include "root" {
  path = find_in_parent_folders("root.hcl")
}
include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}
terraform {
  source = get_env("LOCAL_MODULES_ROOT", "") != "" ? "${get_env("LOCAL_MODULES_ROOT")}//Identity/Managed-identity" : "${include.common.locals.iac_modules_repo}//Identity/Managed-identity?ref=${include.common.locals.module_ref}"
}
inputs = {
  resource_prefix = include.common.locals.names.identity_prefix
}
