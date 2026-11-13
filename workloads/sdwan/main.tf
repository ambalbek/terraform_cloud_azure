# =============================================================================
# Workload: sdwan
# =============================================================================
#
# This file is written once per workload. It loads the environment-specific
# values file (<env>.json) and calls each resource module with for_each over
# the matching map. A missing map key means an empty set — no resources of
# that type are created.
#
# Resource groups are created by bootstrap and looked up here via data source.
# Developers add resources by editing <env>.json, never this file.
# =============================================================================

locals {
  values = jsondecode(file("${path.module}/${var.environment}.json"))

  # Resource maps — default to empty if not present in the values file
  eventhub_namespaces = try(local.values.eventhub_namespaces, {})
}

# =============================================================================
# Data: Resource Group (created by bootstrap)
# =============================================================================

data "azurerm_resource_group" "this" {
  name = "rg-${var.environment}-sdwan"
}

# =============================================================================
# Naming: one instance per resource
# =============================================================================

module "naming_eventhub" {
  source  = "app.terraform.io/<TFC_ORG>/naming/azurerm"
  version = "~> 1.0"

  for_each = local.eventhub_namespaces

  resource_type = "eventhub_namespace"
  location      = each.value.location
  environment   = var.environment
  workload      = "sdwan"
  role          = try(split("-", each.key)[0], each.key)
  instance      = length(split("-", each.key)) > 1 ? split("-", each.key)[1] : null

  tags = {
    owner       = each.value.owner
    cost_center = each.value.cost_center
  }
}

# =============================================================================
# Event Hub Namespaces
# =============================================================================

module "eventhub" {
  source  = "app.terraform.io/<TFC_ORG>/eventhub/azurerm"
  version = "~> 1.0"

  for_each = local.eventhub_namespaces

  namespace_name                = module.naming_eventhub[each.key].name
  resource_group_name           = data.azurerm_resource_group.this.name
  location                      = each.value.location
  namespace_sku                 = try(each.value.namespace_sku, "Standard")
  capacity                      = try(each.value.capacity, 1)
  auto_inflate_enabled          = try(each.value.auto_inflate_enabled, false)
  maximum_throughput_units      = try(each.value.maximum_throughput_units, 0)
  public_network_access_enabled = false
  hubs                          = try(each.value.hubs, {})
  tags                          = module.naming_eventhub[each.key].tags
}

# =============================================================================
# Outputs
# =============================================================================

output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "eventhub_namespace_ids" {
  value = { for k, v in module.eventhub : k => v.namespace_id }
}

output "eventhub_namespace_names" {
  value = { for k, v in module.eventhub : k => v.namespace_name }
}
