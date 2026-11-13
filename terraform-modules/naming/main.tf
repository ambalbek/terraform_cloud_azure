################################################################################
# AVM Regions Utility — authoritative source for geo_code
################################################################################

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.13"

  location         = var.location
  enable_telemetry = false
}

################################################################################
# Naming Logic
################################################################################

locals {
  rules = jsondecode(file("${path.module}/data/naming-rules.json"))

  abbreviation = local.rules.abbreviations[var.resource_type]

  # Use AVM regions utility for geo_code; fall back to JSON override if needed
  avm_region_code = try(module.regions.regions_by_name[var.location].geo_code, null)
  json_override   = lookup(local.rules.region_code_overrides, var.location, null)
  region_code     = coalesce(local.json_override, local.avm_region_code, "")

  # Build the list of name components, filtering out nulls/empty strings
  components = compact([
    local.abbreviation,
    local.region_code,
    var.environment,
    var.workload,
    var.role,
    var.instance,
  ])

  # Standard hyphenated name
  raw_name = join("-", local.components)

  # Check if this resource type has special rules
  special = lookup(local.rules.special_rules, var.resource_type, null)

  # Apply special rules for storage accounts (no hyphens) and key vaults (max length)
  name = (
    local.special != null
    ? (
      local.special.allow_hyphens
      # Has max_length but keeps hyphens (key_vault)
      ? substr(local.raw_name, 0, min(length(local.raw_name), local.special.max_length))
      # No hyphens allowed (storage_account) - remove hyphens then truncate
      : substr(replace(local.raw_name, "-", ""), 0, min(length(replace(local.raw_name, "-", "")), local.special.max_length))
    )
    : local.raw_name
  )

  # Standard tags applied to every resource
  standard_tags = {
    environment = var.environment
    workload    = var.workload
    region      = var.location
    managed_by  = "terraform"
  }
}

# Validate that a region code was resolved
check "region_code_exists" {
  assert {
    condition     = local.region_code != ""
    error_message = "No geo_code found for location '${var.location}'. Contact the Cloud COE to add this region."
  }
}
