variable "workload" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "role" { type = string default = null }
variable "instance" { type = string default = null }
variable "resource_group_name" { type = string }
variable "account_tier" { type = string default = "Standard" }
variable "replication_type" { type = string default = "GRS" }
variable "account_kind" { type = string default = "StorageV2" }
variable "access_tier" { type = string default = "Hot" }
variable "owner" { type = string }
variable "cost_center" { type = string }
