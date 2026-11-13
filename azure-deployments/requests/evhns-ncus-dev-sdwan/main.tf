terraform {
  cloud {
    organization = "<TFC_ORG>"
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

  resource_type = "eventhub_namespace"
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
# Event Hub
################################################################################

module "eventhub" {
  source  = "app.terraform.io/<TFC_ORG>/eventhub/azurerm"
  version = "~> 1.0"

  namespace_name                = module.naming.name
  resource_group_name           = var.resource_group_name
  location                      = var.region
  namespace_sku                 = var.namespace_sku
  capacity                      = var.capacity
  auto_inflate_enabled          = var.auto_inflate_enabled
  maximum_throughput_units      = var.maximum_throughput_units
  public_network_access_enabled = false
  hubs                          = var.hubs
  tags                          = module.naming.tags
}

################################################################################
# Outputs
################################################################################

output "namespace_name" {
  value = module.eventhub.namespace_name
}

output "namespace_id" {
  value = module.eventhub.namespace_id
}

output "hub_ids" {
  value = module.eventhub.hub_ids
}
