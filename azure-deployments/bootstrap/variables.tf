variable "tfc_org" {
  type        = string
  description = "HCP Terraform organization name"
}

variable "tfc_token" {
  type        = string
  sensitive   = true
  description = "HCP Terraform API token with organization-level access"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD Tenant ID"
}

variable "subscriptions" {
  type        = map(string)
  description = "Map of project name to Azure Subscription ID (e.g. {prod = \"...\", nonprod = \"...\"})"

  validation {
    condition     = alltrue([for k, v in var.subscriptions : can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", v))])
    error_message = "Each subscription value must be a valid UUID."
  }
}

variable "github_org" {
  type        = string
  description = "GitHub organization name"
}

variable "github_repo" {
  type        = string
  default     = "azure-deployments"
  description = "GitHub repository name for the deployments repo"
}
