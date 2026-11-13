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

module "storage_account" {
  source  = "app.terraform.io/<TFC_ORG>/storage-account/azurerm"
  version = "~> 1.0"

  workload                   = var.workload
  environment                = var.environment
  location                   = var.region
  role                       = var.role
  instance                   = var.instance
  resource_group_name        = var.resource_group_name
  account_tier               = var.account_tier
  account_replication_type   = var.replication_type
  account_kind               = var.account_kind
  access_tier                = var.access_tier
  enable_versioning          = var.enable_versioning
  enable_blob_soft_delete    = var.enable_blob_soft_delete
  soft_delete_retention_days = var.soft_delete_retention_days
  enable_diagnostics         = var.enable_diagnostics
  owner                      = var.owner
  cost_center                = var.cost_center
}

output "storage_account_name" {
  value = module.storage_account.name
}

output "storage_account_id" {
  value = module.storage_account.id
}
