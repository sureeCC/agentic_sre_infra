include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = find_in_parent_folders("common.hcl")
  expose = true
}

terraform {
  source = "${include.common.locals.iac_modules_repo}//resource-group${include.common.locals.module_ref == "" ? "" : "?ref=${include.common.locals.module_ref}"}"
}

inputs = {
  name                  = include.common.locals.resource_group_name
  location              = include.common.locals.resource_group_location
  tags                  = include.common.locals.tags
  enforce_required_tags = include.common.locals.manage_tags
}
