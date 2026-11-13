variable "workload"                   { type = string }
variable "environment"                { type = string }
variable "region"                     { type = string }
variable "role"                       { type = string  default = null }
variable "instance"                   { type = string  default = null }
variable "resource_group_name"        { type = string }
variable "account_tier"               { type = string  default = "Standard" }
variable "replication_type"           { type = string  default = "GRS" }
variable "account_kind"               { type = string  default = "StorageV2" }
variable "access_tier"                { type = string  default = "Hot" }
variable "enable_versioning"          { type = bool    default = true }
variable "enable_blob_soft_delete"    { type = bool    default = true }
variable "soft_delete_retention_days" { type = number  default = 30 }
variable "enable_diagnostics"         { type = bool    default = false }
variable "owner"                      { type = string }
variable "cost_center"                { type = string }
