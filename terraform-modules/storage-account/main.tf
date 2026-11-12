################################################################################
# Naming
################################################################################

module "naming" {
  source = "../naming"

  resource_type = "storage_account"
  location      = var.location
  environment   = var.environment
  workload      = var.workload
  role          = var.role
  instance      = var.instance

  tags = merge(var.tags, {
    owner       = var.owner
    cost_center = var.cost_center
  })
}

module "rg_naming" {
  source = "../naming"

  resource_type = "resource_group"
  location      = var.location
  environment   = var.environment
  workload      = var.workload

  tags = merge(var.tags, {
    owner       = var.owner
    cost_center = var.cost_center
  })
}

################################################################################
# Storage Account
################################################################################

resource "azurerm_storage_account" "this" {
  name                = module.naming.name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  account_kind             = var.account_kind
  access_tier              = var.access_tier

  # Secure defaults
  public_network_access_enabled   = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = module.naming.tags

  blob_properties {
    versioning_enabled = var.enable_versioning

    dynamic "delete_retention_policy" {
      for_each = var.enable_blob_soft_delete ? [1] : []

      content {
        days = var.soft_delete_retention_days
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = var.enable_container_delete_retention ? [1] : []

      content {
        days = var.container_delete_retention_days
      }
    }
  }
}

################################################################################
# Diagnostic Settings (optional)
################################################################################

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.enable_diagnostics && var.log_analytics_workspace_id != null ? 1 : 0

  name                       = "${azurerm_storage_account.this.name}-diag"
  target_resource_id         = azurerm_storage_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  metric {
    category = "Transaction"
    enabled  = true
  }
}
