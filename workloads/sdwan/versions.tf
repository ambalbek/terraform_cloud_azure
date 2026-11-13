terraform {
  required_version = ">= 1.9.0"

  cloud {
    organization = "<TFC_ORG>"
    # Workspace is selected dynamically by the CI workflow.
    # Each workspace sets var.environment (dev, uat, prod).
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
