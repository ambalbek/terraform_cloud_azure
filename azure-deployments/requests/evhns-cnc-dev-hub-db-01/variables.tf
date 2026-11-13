variable "workload"            { type = string }
variable "environment"         { type = string }
variable "region"              { type = string }
variable "role"                { type = string default = null }
variable "instance"            { type = string default = null }
variable "resource_group_name" { type = string }
variable "owner"               { type = string }
variable "cost_center"         { type = string }
variable "namespace_sku"           { type = string default = "Standard" }
variable "capacity"                { type = number default = 1 }
variable "auto_inflate_enabled"    { type = bool   default = false }
variable "maximum_throughput_units" { type = number default = 0 }
variable "hubs" {
  type = map(object({
    partition_count   = number
    message_retention = number
    consumer_groups = optional(map(object({
      user_metadata = optional(string, "")
    })), {})
  }))
  default = {}
}
