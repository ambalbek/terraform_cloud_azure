# -------------------------------------------------------
# Reference name tests
# -------------------------------------------------------

# 1. rg-cus-prod-sdwan (Central US, no role, no instance)
run "rg_cus_prod_sdwan" {
  command = plan

  variables {
    resource_type = "resource_group"
    location      = "centralus"
    environment   = "prod"
    workload      = "sdwan"
  }

  assert {
    condition     = output.name == "rg-cus-prod-sdwan"
    error_message = "Expected 'rg-cus-prod-sdwan', got '${output.name}'"
  }
}

# 2. rg-ncus-prod-sdwan-fgt (with role)
run "rg_ncus_prod_sdwan_fgt" {
  command = plan

  variables {
    resource_type = "resource_group"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt"
  }

  assert {
    condition     = output.name == "rg-ncus-prod-sdwan-fgt"
    error_message = "Expected 'rg-ncus-prod-sdwan-fgt', got '${output.name}'"
  }
}

# 3. vm-ncus-prod-sdwan-fgt-01 (with role and instance)
run "vm_ncus_prod_sdwan_fgt_01" {
  command = plan

  variables {
    resource_type = "virtual_machine"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt"
    instance      = "01"
  }

  assert {
    condition     = output.name == "vm-ncus-prod-sdwan-fgt-01"
    error_message = "Expected 'vm-ncus-prod-sdwan-fgt-01', got '${output.name}'"
  }
}

# 4. vm-ncus-nonprod-sdwan-probe (no instance)
run "vm_ncus_nonprod_sdwan_probe" {
  command = plan

  variables {
    resource_type = "virtual_machine"
    location      = "northcentralus"
    environment   = "nonprod"
    workload      = "sdwan"
    role          = "probe"
  }

  assert {
    condition     = output.name == "vm-ncus-nonprod-sdwan-probe"
    error_message = "Expected 'vm-ncus-nonprod-sdwan-probe', got '${output.name}'"
  }
}

# 5. vnet-ncus-prod-sdwan-fgt
run "vnet_ncus_prod_sdwan_fgt" {
  command = plan

  variables {
    resource_type = "virtual_network"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt"
  }

  assert {
    condition     = output.name == "vnet-ncus-prod-sdwan-fgt"
    error_message = "Expected 'vnet-ncus-prod-sdwan-fgt', got '${output.name}'"
  }
}

# 6. snet-ncus-prod-sdwan-fgt-internal
run "snet_ncus_prod_sdwan_fgt_internal" {
  command = plan

  variables {
    resource_type = "subnet"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt-internal"
  }

  assert {
    condition     = output.name == "snet-ncus-prod-sdwan-fgt-internal"
    error_message = "Expected 'snet-ncus-prod-sdwan-fgt-internal', got '${output.name}'"
  }
}

# 7. nic-ncus-prod-sdwan-fgt-internal-01
run "nic_ncus_prod_sdwan_fgt_internal_01" {
  command = plan

  variables {
    resource_type = "network_interface"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt-internal"
    instance      = "01"
  }

  assert {
    condition     = output.name == "nic-ncus-prod-sdwan-fgt-internal-01"
    error_message = "Expected 'nic-ncus-prod-sdwan-fgt-internal-01', got '${output.name}'"
  }
}

# 8. pip-ncus-prod-sdwan-fgt-mgmt-01
run "pip_ncus_prod_sdwan_fgt_mgmt_01" {
  command = plan

  variables {
    resource_type = "public_ip"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt-mgmt"
    instance      = "01"
  }

  assert {
    condition     = output.name == "pip-ncus-prod-sdwan-fgt-mgmt-01"
    error_message = "Expected 'pip-ncus-prod-sdwan-fgt-mgmt-01', got '${output.name}'"
  }
}

# 9. pip-ncus-prod-sdwan-fgt-mgmt-02
run "pip_ncus_prod_sdwan_fgt_mgmt_02" {
  command = plan

  variables {
    resource_type = "public_ip"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt-mgmt"
    instance      = "02"
  }

  assert {
    condition     = output.name == "pip-ncus-prod-sdwan-fgt-mgmt-02"
    error_message = "Expected 'pip-ncus-prod-sdwan-fgt-mgmt-02', got '${output.name}'"
  }
}

# 10. pip-ncus-prod-sdwan-fgt-cluster (no instance)
run "pip_ncus_prod_sdwan_fgt_cluster" {
  command = plan

  variables {
    resource_type = "public_ip"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt-cluster"
  }

  assert {
    condition     = output.name == "pip-ncus-prod-sdwan-fgt-cluster"
    error_message = "Expected 'pip-ncus-prod-sdwan-fgt-cluster', got '${output.name}'"
  }
}

# 11. vwan-cus-prod-sdwan (Central US)
run "vwan_cus_prod_sdwan" {
  command = plan

  variables {
    resource_type = "virtual_wan"
    location      = "centralus"
    environment   = "prod"
    workload      = "sdwan"
  }

  assert {
    condition     = output.name == "vwan-cus-prod-sdwan"
    error_message = "Expected 'vwan-cus-prod-sdwan', got '${output.name}'"
  }
}

# 12. vhub-ncus-prod-sdwan
run "vhub_ncus_prod_sdwan" {
  command = plan

  variables {
    resource_type = "virtual_hub"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
  }

  assert {
    condition     = output.name == "vhub-ncus-prod-sdwan"
    error_message = "Expected 'vhub-ncus-prod-sdwan', got '${output.name}'"
  }
}

# 13. lbe-ncus-prod-sdwan-fgt
run "lbe_ncus_prod_sdwan_fgt" {
  command = plan

  variables {
    resource_type = "load_balancer_external"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
    role          = "fgt"
  }

  assert {
    condition     = output.name == "lbe-ncus-prod-sdwan-fgt"
    error_message = "Expected 'lbe-ncus-prod-sdwan-fgt', got '${output.name}'"
  }
}

# -------------------------------------------------------
# Storage account test - no hyphens, alphanumeric only
# -------------------------------------------------------

# 14. Storage account: stncusprodsdwan
run "storage_account_no_hyphens" {
  command = plan

  variables {
    resource_type = "storage_account"
    location      = "northcentralus"
    environment   = "prod"
    workload      = "sdwan"
  }

  assert {
    condition     = output.name == "stncusprodsdwan"
    error_message = "Expected 'stncusprodsdwan', got '${output.name}'"
  }
}

# -------------------------------------------------------
# Invalid region test - should produce a check warning
# -------------------------------------------------------

# 15. Unknown region (brazilsouth) - check block emits a warning
run "unknown_region_brazilsouth" {
  command = plan

  variables {
    resource_type = "resource_group"
    location      = "brazilsouth"
    environment   = "prod"
    workload      = "sdwan"
  }

  # Region code is empty string; compact() removes it so name has no region segment.
  # The check block will emit a warning about the missing region code.
  assert {
    condition     = output.name == "rg-prod-sdwan"
    error_message = "Expected 'rg-prod-sdwan' for unmapped region, got '${output.name}'"
  }
}

# -------------------------------------------------------
# Map key parsing tests (workload main.tf for_each keys)
# -------------------------------------------------------
# In workloads/<name>/main.tf the map key is split on "-" to derive role and
# instance.  These tests verify the naming module produces the correct output
# for typical key patterns.

# 16. Key "db-01" => role="db", instance="01"
#     eventhub_namespace in northcentralus dev sdwan
run "evhns_ncus_dev_sdwan_db_01" {
  command = plan

  variables {
    resource_type = "eventhub_namespace"
    location      = "northcentralus"
    environment   = "dev"
    workload      = "sdwan"
    role          = "db"
    instance      = "01"
  }

  assert {
    condition     = output.name == "evhns-ncus-dev-sdwan-db-01"
    error_message = "Expected 'evhns-ncus-dev-sdwan-db-01', got '${output.name}'"
  }
}

# 17. Key "default" => role=null, instance=null
#     The workload main.tf strips "default" before passing to naming, so the
#     naming module receives role=null. This test verifies that role=null
#     produces a name without a trailing role segment.
#     eventhub_namespace in centralus dev sdwan
run "evhns_cus_dev_sdwan_no_role" {
  command = plan

  variables {
    resource_type = "eventhub_namespace"
    location      = "centralus"
    environment   = "dev"
    workload      = "sdwan"
  }

  assert {
    condition     = output.name == "evhns-cus-dev-sdwan"
    error_message = "Expected 'evhns-cus-dev-sdwan', got '${output.name}'"
  }
}

# 18. role="db", instance=null => name includes role but no instance
#     eventhub_namespace in northcentralus dev sdwan
run "evhns_ncus_dev_sdwan_db_no_instance" {
  command = plan

  variables {
    resource_type = "eventhub_namespace"
    location      = "northcentralus"
    environment   = "dev"
    workload      = "sdwan"
    role          = "db"
  }

  assert {
    condition     = output.name == "evhns-ncus-dev-sdwan-db"
    error_message = "Expected 'evhns-ncus-dev-sdwan-db', got '${output.name}'"
  }
}
