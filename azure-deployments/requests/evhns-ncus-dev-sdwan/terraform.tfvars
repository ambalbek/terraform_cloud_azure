workload            = "sdwan"
environment         = "dev"
region              = "northcentralus"
role                = null
instance            = null
resource_group_name = "rg-ncus-dev-sdwan"
owner               = "cloud-coe"
cost_center         = "CC-1234"

namespace_sku           = "Standard"
capacity                = 1
auto_inflate_enabled    = false
maximum_throughput_units = 0

hubs = {
  "events" = {
    partition_count   = 4
    message_retention = 7
    consumer_groups = {
      "app-consumer" = {
        user_metadata = "Application consumer group"
      }
    }
  }
}
