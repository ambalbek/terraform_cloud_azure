terraform {
  cloud {
    organization = "<TFC_ORG>"
    # Workspace is set dynamically by the CI workflow
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}

################################################################################
# Naming
################################################################################

module "naming" {
  source  = "app.terraform.io/<TFC_ORG>/naming/azurerm"
  version = "~> 1.0"

  resource_type = "storage_account"
  location      = var.region
  environment   = var.environment
  workload      = var.workload
  role          = var.role
  instance      = var.instance

  tags = {
    owner       = var.owner
    cost_center = var.cost_center
  }
}

################################################################################
# Storage Account (Azure Verified Module)
################################################################################

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.11"

  name                          = module.naming.name
  location                      = var.region
  resource_group_name           = var.resource_group_name
  account_tier                  = var.account_tier
  account_replication_type      = var.replication_type
  account_kind                  = var.account_kind
  access_tier                   = var.access_tier
  public_network_access_enabled = false
  min_tls_version               = "TLS1_2"
  shared_access_key_enabled     = false

  tags = module.naming.tags
}

################################################################################
# Outputs
################################################################################

output "storage_account_name" {
  value = module.storage_account.name
}

output "storage_account_id" {
  value = module.storage_account.resource_id
}
