variable "environment" {
  type        = string
  description = "Environment code, set by the workspace (dev, uat, prod)."

  validation {
    condition     = contains(["prod", "dev", "test", "qa", "uat", "nonprod"], var.environment)
    error_message = "Must be one of: prod, dev, test, qa, uat, nonprod."
  }
}
