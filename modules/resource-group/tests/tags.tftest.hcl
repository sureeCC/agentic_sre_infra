mock_provider "azurerm" {}

variables {
  name     = "test"
  location = "eastus"
}

run "untagged_poc" {
  command = plan
  variables {
    tags                  = {}
    enforce_required_tags = false
  }
}

run "missing_required_tags" {
  command = plan
  variables {
    tags = {}
  }
  expect_failures = [azurerm_resource_group.this]
}

run "empty_required_tag" {
  command = plan
  variables {
    tags = {
      environment         = "poc"
      workload            = "agentic-sre"
      owner               = "   "
      cost_center         = "sre-poc"
      data_classification = "internal"
    }
  }
  expect_failures = [azurerm_resource_group.this]
}

run "valid_required_tags" {
  command = plan
  variables {
    tags = {
      environment         = "poc"
      workload            = "agentic-sre"
      owner               = "platform-engineering"
      cost_center         = "sre-poc"
      data_classification = "internal"
    }
  }
}
