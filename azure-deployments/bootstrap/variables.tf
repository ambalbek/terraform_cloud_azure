variable "tfc_org" {
  type        = string
  description = "HCP Terraform organization name."
}

variable "tfc_token" {
  type        = string
  sensitive   = true
  description = "HCP Terraform API token with organization-level access."
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID (single subscription)."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Must be a valid UUID."
  }
}

variable "github_org" {
  type        = string
  description = "GitHub organization name."
}

variable "github_repo" {
  type        = string
  default     = "terraform_cloud_azure"
  description = "GitHub repository name."
}

variable "workloads" {
  type        = map(set(string))
  description = <<-EOT
    Map of workload name to its environments.
    Example: { sdwan = ["dev", "uat", "prod"] }
  EOT

  validation {
    condition = alltrue(flatten([
      for wl, envs in var.workloads : [
        for env in envs : contains(["prod", "dev", "test", "qa", "uat", "nonprod"], env)
      ]
    ]))
    error_message = "Each environment must be one of: prod, dev, test, qa, uat, nonprod."
  }
}

variable "allowed_regions" {
  type        = list(string)
  description = "Azure regions allowed by policy."
  default     = ["centralus", "canadacentral", "northcentralus", "southcentralus", "westeurope", "northeurope", "australiaeast", "australiasoutheast"]
}

variable "required_tags" {
  type        = map(string)
  description = "Tags required by Azure Policy (tag name → description)."
  default = {
    environment = "Environment code"
    workload    = "Workload name"
    owner       = "Resource owner"
    cost_center = "Cost center"
    managed_by  = "Management tool"
  }
}
