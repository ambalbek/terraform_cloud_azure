variable "resource_type" {
  type        = string
  description = "Logical resource type name matching a key in the abbreviations map of naming-rules.json."
}

variable "location" {
  type        = string
  description = "Full Azure region name, e.g. 'northcentralus'. Must exist in the region_codes map."
}

variable "environment" {
  type        = string
  description = "Environment code. Must be one of: prod, dev, test, qa, uat, nonprod."

  validation {
    condition     = contains(["prod", "dev", "test", "qa", "uat", "nonprod"], var.environment)
    error_message = "Environment must be one of: prod, dev, test, qa, uat, nonprod."
  }
}

variable "workload" {
  type        = string
  description = "Workload or project name the resource belongs to."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.workload))
    error_message = "Workload must be lowercase alphanumeric characters and hyphens only."
  }
}

variable "role" {
  type        = string
  default     = null
  description = "Optional role to distinguish same-type resources. Lowercase alphanumeric and hyphens only."

  validation {
    condition     = var.role == null || can(regex("^[a-z0-9-]+$", var.role))
    error_message = "Role must be lowercase alphanumeric characters and hyphens only."
  }
}

variable "instance" {
  type        = string
  default     = null
  description = "Optional two-digit instance number (e.g. '01', '02'). Only used when multiple equivalent resources exist."

  validation {
    condition     = var.instance == null || can(regex("^[0-9]{2}$", var.instance))
    error_message = "Instance must be exactly two digits, e.g. '01'."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to merge with the standard tags."
}
