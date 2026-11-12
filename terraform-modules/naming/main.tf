locals {
  rules = jsondecode(file("${path.module}/data/naming-rules.json"))

  abbreviation = local.rules.abbreviations[var.resource_type]
  region_code  = lookup(local.rules.region_codes, var.location, "")

  # Build the list of name components, filtering out nulls
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

# Validate that the region code was found
check "region_code_exists" {
  assert {
    condition     = local.region_code != ""
    error_message = "No region code found for location '${var.location}'. Add it to naming-rules.json region_codes."
  }
}
