resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
  tags     = var.tags

  lifecycle {
    precondition {
      condition = !var.enforce_required_tags || alltrue([
        for required_tag in ["environment", "workload", "owner", "cost_center", "data_classification"] :
        contains(keys(var.tags), required_tag) && length(trimspace(var.tags[required_tag])) > 0
      ])
      error_message = "tags must include non-empty environment, workload, owner, cost_center, and data_classification values."
    }
  }
}
