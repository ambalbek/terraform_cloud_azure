################################################################################
# Naming
################################################################################

variable "workload" {
  type        = string
  description = "Workload or project name. Passed to the naming module."
}

variable "environment" {
  type        = string
  description = "Environment code (e.g. prod, dev, test). Passed to the naming module."
}

variable "location" {
  type        = string
  description = "Full Azure region name, e.g. 'northcentralus'."
}

variable "role" {
  type        = string
  default     = null
  description = "Optional role to distinguish same-type resources. Passed to the naming module."
}

variable "instance" {
  type        = string
  default     = null
  description = "Optional two-digit instance number (e.g. '01'). Passed to the naming module."
}

################################################################################
# Resource configuration
################################################################################

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group where the storage account will be created."
}

variable "account_tier" {
  type        = string
  default     = "Standard"
  description = "Performance tier of the storage account."

  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "account_tier must be Standard or Premium."
  }
}

variable "account_replication_type" {
  type        = string
  default     = "GRS"
  description = "Replication strategy for the storage account."

  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "GZRS"], var.account_replication_type)
    error_message = "account_replication_type must be one of: LRS, GRS, ZRS, GZRS."
  }
}

variable "account_kind" {
  type        = string
  default     = "StorageV2"
  description = "Kind of storage account."

  validation {
    condition     = contains(["StorageV2", "BlobStorage"], var.account_kind)
    error_message = "account_kind must be StorageV2 or BlobStorage."
  }
}

variable "access_tier" {
  type        = string
  default     = "Hot"
  description = "Default access tier for blob data."

  validation {
    condition     = contains(["Hot", "Cool"], var.access_tier)
    error_message = "access_tier must be Hot or Cool."
  }
}

################################################################################
# Blob properties
################################################################################

variable "enable_versioning" {
  type        = bool
  default     = true
  description = "Enable blob versioning."
}

variable "enable_blob_soft_delete" {
  type        = bool
  default     = true
  description = "Enable soft delete for blobs."
}

variable "soft_delete_retention_days" {
  type        = number
  default     = 30
  description = "Number of days to retain soft-deleted blobs."

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "enable_container_delete_retention" {
  type        = bool
  default     = true
  description = "Enable soft delete for containers."
}

variable "container_delete_retention_days" {
  type        = number
  default     = 30
  description = "Number of days to retain soft-deleted containers."

  validation {
    condition     = var.container_delete_retention_days >= 1 && var.container_delete_retention_days <= 365
    error_message = "container_delete_retention_days must be between 1 and 365."
  }
}

################################################################################
# Diagnostics
################################################################################

variable "enable_diagnostics" {
  type        = bool
  default     = false
  description = "Enable diagnostic settings for the storage account."
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
  description = "Resource ID of the Log Analytics workspace for diagnostic logs."
}

################################################################################
# Tagging
################################################################################

variable "owner" {
  type        = string
  description = "Owner of the resource, used for tagging."
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing, used for tagging."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge with the standard tags."
}
