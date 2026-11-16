# =============================================================================
# Workload: sdwan
# =============================================================================
#
# This file is written once per workload. It loads the environment-specific
# values file (<env>.json) and calls each resource module with for_each over
# the matching map. A missing map key means an empty set — no resources of
# that type are created.
#
# Resource groups are self-service: declared in <env>.json alongside other
# resources. Other resources reference them by key via local.resource_groups.
# =============================================================================

locals {
  values = jsondecode(file("${path.module}/${var.environment}.json"))

  # Resource maps — default to empty if not present in the values file
  resource_groups     = try(local.values.resource_groups, {})
  eventhub_namespaces = try(local.values.eventhub_namespaces, {})

  # Helper to parse role and instance from a map key like "db-01" or "default"
  # "default" key → role=null, instance=null (no suffix in the name)
  parse_key = {
    for key in distinct(concat(keys(local.resource_groups), keys(local.eventhub_namespaces))) : key => {
      role     = key == "default" ? null : (length(split("-", key)) > 1 && can(regex("^[0-9]{2}$", split("-", key)[length(split("-", key)) - 1])) ? join("-", slice(split("-", key), 0, length(split("-", key)) - 1)) : key)
      instance = key == "default" ? null : (length(split("-", key)) > 1 && can(regex("^[0-9]{2}$", split("-", key)[length(split("-", key)) - 1])) ? split("-", key)[length(split("-", key)) - 1] : null)
    }
  }
}

# =============================================================================
# Resource Groups
# =============================================================================

module "naming_rg" {
  source  = "app.terraform.io/<TFC_ORG>/naming/azurerm"
  version = "~> 1.0"

  for_each = local.resource_groups

  resource_type = "resource_group"
  location      = each.value.location
  environment   = var.environment
  workload      = "sdwan"
  role          = local.parse_key[each.key].role
  instance      = local.parse_key[each.key].instance

  tags = {
    owner       = each.value.owner
    cost_center = each.value.cost_center
  }
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = module.naming_rg[each.key].name
  location = each.value.location
  tags     = module.naming_rg[each.key].tags
}

# CanNotDelete locks on prod resource groups
resource "azurerm_management_lock" "rg" {
  for_each = {
    for k, v in local.resource_groups : k => v if var.environment == "prod"
  }

  name       = "CanNotDelete"
  scope      = azurerm_resource_group.this[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Prod resource group — removal requires Owner to delete lock first"
}

# =============================================================================
# Naming: Event Hub Namespaces
# =============================================================================

module "naming_eventhub" {
  source  = "app.terraform.io/<TFC_ORG>/naming/azurerm"
  version = "~> 1.0"

  for_each = local.eventhub_namespaces

  resource_type = "eventhub_namespace"
  location      = each.value.location
  environment   = var.environment
  workload      = "sdwan"
  role          = local.parse_key[each.key].role
  instance      = local.parse_key[each.key].instance

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
  resource_group_name           = azurerm_resource_group.this[each.value.resource_group_key].name
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
# Note: prevent_destroy and for_each modules
# =============================================================================
#
# Terraform does not support lifecycle { prevent_destroy = true } on module
# blocks that use for_each (the meta-argument is not allowed alongside
# lifecycle on module calls).  The following stateful resources WOULD have
# prevent_destroy if they were defined inline:
#
#   - azurerm_eventhub_namespace
#   - azurerm_storage_account
#   - azurerm_key_vault
#
# Instead, stateful-resource protection is provided by two mechanisms:
#
#   1. CanNotDelete management locks on prod resource groups (applied by the
#      bootstrap module).  These locks require Owner role to remove, so a
#      contributor-level apply cannot accidentally destroy the RG or its
#      children.
#
#   2. The allow-destroy workflow guard in plan.yml / apply.yml.  If a
#      terraform plan contains any destroy actions the PR must carry the
#      "allow-destroy" label before merge is permitted.  This gives reviewers
#      an explicit gate before any resource removal reaches Azure.
#
# Together these two layers provide equivalent (or stronger) protection to
# prevent_destroy for resources managed via for_each modules.
# =============================================================================

# =============================================================================
# Outputs
# =============================================================================

output "resource_group_names" {
  value = { for k, v in azurerm_resource_group.this : k => v.name }
}

output "resource_group_ids" {
  value = { for k, v in azurerm_resource_group.this : k => v.id }
}

output "eventhub_namespace_ids" {
  value = { for k, v in module.eventhub : k => v.namespace_id }
}

output "eventhub_namespace_names" {
  value = { for k, v in module.eventhub : k => v.namespace_name }
}
