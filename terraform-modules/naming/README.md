# Naming Module

Generates standardized resource names for Azure resources following a consistent naming convention.

## Naming Standard

```
<abbreviation>-<region code>-<environment>-<workload>[-<role>][-<instance>]
```

**Example:** `nic-ncus-prod-sdwan-fgt-internal-01`

| Component    | Description                                          |
|-------------|------------------------------------------------------|
| abbreviation | CAF abbreviation for the resource type               |
| region code  | Lowercase Microsoft geo code (e.g. ncus, cus, we)   |
| environment  | One of: prod, dev, test, qa, uat, nonprod            |
| workload     | Project or workload the resource belongs to          |
| role         | Optional - distinguishes same-type resources         |
| instance     | Optional - two digits (01, 02) for multiple equivalents |

### Special Cases

- **Storage accounts:** 3-24 lowercase alphanumeric characters, no hyphens. The module removes hyphens and truncates from the right if the name exceeds 24 characters.
- **Key Vaults:** 3-24 characters, alphanumeric and hyphens allowed. The module truncates from the right if the name exceeds 24 characters.

## Usage

```hcl
module "vm_name" {
  source = "../naming"

  resource_type = "virtual_machine"
  location      = "northcentralus"
  environment   = "prod"
  workload      = "sdwan"
  role          = "fgt"
  instance      = "01"
}

# vm_name.name => "vm-ncus-prod-sdwan-fgt-01"
```

## Inputs

| Name          | Type        | Required | Default | Description                              |
|--------------|-------------|----------|---------|------------------------------------------|
| resource_type | string      | yes      |         | Logical name matching a key in abbreviations |
| location      | string      | yes      |         | Full Azure region name                   |
| environment   | string      | yes      |         | Environment code (prod, dev, etc.)       |
| workload      | string      | yes      |         | Workload or project name                 |
| role          | string      | no       | null    | Distinguishes same-type resources        |
| instance      | string      | no       | null    | Two-digit instance number                |
| tags          | map(string) | no       | {}      | Additional tags to merge                 |

## Outputs

| Name | Type        | Description                                |
|------|-------------|--------------------------------------------|
| name | string      | The generated resource name                |
| tags | map(string) | Standard tags merged with additional tags  |

## Adding New Resource Types, Regions, or Workloads

All naming data is stored in `data/naming-rules.json`. To extend the module:

1. **New resource type:** Add an entry to the `abbreviations` map with the logical name as key and the CAF abbreviation as value. If the type has length restrictions or hyphen rules, also add entries to `special_rules` and `max_lengths`.

2. **New region:** Add an entry to the `region_codes` map with the full Azure region name as key and the geo code as value.

3. **New workload:** Add the workload name to the `workloads` array.

No Terraform code changes are needed -- just edit the JSON file.

## Running Tests

```bash
cd terraform-modules/naming
terraform init
terraform test
```
