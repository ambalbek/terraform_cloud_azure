"""
Checkov custom policy: Name Matches Naming Standard

Ensures that resource names follow the naming convention:
  <abbreviation>-<regioncode>-<env>-<workload>[-<role>][-<instance>]

For storage accounts (no hyphens allowed):
  <abbreviation><regioncode><env><workload>[<role>][<instance>]

Uses the naming-rules.json data to validate abbreviations, region codes,
environments, and workloads.
"""

import json
import os
import re
from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class NameMatchesStandard(BaseResourceCheck):
    def __init__(self):
        name = "Ensure resource names match the naming convention"
        id = "CKV_AZURE_CUSTOM_004"
        supported_resources = [
            "azurerm_resource_group",
            "azurerm_storage_account",
            "azurerm_key_vault",
            "azurerm_virtual_network",
            "azurerm_subnet",
            "azurerm_network_interface",
            "azurerm_public_ip",
            "azurerm_virtual_machine",
            "azurerm_linux_virtual_machine",
            "azurerm_windows_virtual_machine",
            "azurerm_managed_disk",
            "azurerm_availability_set",
            "azurerm_lb",
            "azurerm_function_app",
            "azurerm_virtual_wan",
            "azurerm_virtual_hub",
        ]
        categories = [CheckCategories.CONVENTION]

        self.rules = self._load_rules()
        self.patterns = self._build_patterns()

        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def _load_rules(self):
        """Load naming-rules.json."""
        search_paths = [
            os.path.join(os.path.dirname(__file__), "..", "..", "terraform-modules", "naming", "data", "naming-rules.json"),
            os.path.join(os.path.dirname(__file__), "..", "..", "..", "terraform-modules", "naming", "data", "naming-rules.json"),
        ]
        for path in search_paths:
            abs_path = os.path.abspath(path)
            if os.path.exists(abs_path):
                with open(abs_path, "r") as f:
                    return json.load(f)

        # Fallback defaults
        return {
            "abbreviations": {"storage_account": "st", "resource_group": "rg"},
            "region_codes": {"northcentralus": "ncus"},
            "environments": ["prod", "dev", "test", "qa", "uat", "nonprod"],
            "workloads": ["sdwan", "hub", "probe", "core", "app"],
            "special_rules": {"storage_account": {"allow_hyphens": False}},
        }

    def _build_patterns(self):
        """Build regex patterns for resource types."""
        abbreviations = self.rules.get("abbreviations", {})
        region_codes = list(self.rules.get("region_codes", {}).values())
        environments = self.rules.get("environments", [])
        workloads = self.rules.get("workloads", [])
        special_rules = self.rules.get("special_rules", {})

        # Map Terraform resource type to abbreviation key
        resource_type_to_abbr_key = {
            "azurerm_resource_group": "resource_group",
            "azurerm_storage_account": "storage_account",
            "azurerm_key_vault": "key_vault",
            "azurerm_virtual_network": "virtual_network",
            "azurerm_subnet": "subnet",
            "azurerm_network_interface": "network_interface",
            "azurerm_public_ip": "public_ip",
            "azurerm_virtual_machine": "virtual_machine",
            "azurerm_linux_virtual_machine": "virtual_machine",
            "azurerm_windows_virtual_machine": "virtual_machine",
            "azurerm_managed_disk": "managed_disk",
            "azurerm_availability_set": "availability_set",
            "azurerm_lb": "load_balancer_internal",
            "azurerm_function_app": "function_app",
            "azurerm_virtual_wan": "virtual_wan",
            "azurerm_virtual_hub": "virtual_hub",
        }

        # Escape workloads for regex (handle hyphens)
        workload_pattern = "|".join(re.escape(w) for w in workloads)
        region_pattern = "|".join(re.escape(r) for r in region_codes)
        env_pattern = "|".join(re.escape(e) for e in environments)

        patterns = {}
        for resource_type, abbr_key in resource_type_to_abbr_key.items():
            abbr = abbreviations.get(abbr_key)
            if not abbr:
                continue

            no_hyphens = special_rules.get(abbr_key, {}).get("allow_hyphens", True) is False

            if no_hyphens:
                # No-hyphen pattern: st<region><env><workload>[<role>][<instance>]
                # Strip hyphens from workloads for matching
                workload_nohyphen = "|".join(re.escape(w.replace("-", "")) for w in workloads)
                pattern = (
                    f"^{re.escape(abbr)}"
                    f"({region_pattern})"
                    f"({env_pattern})"
                    f"({workload_nohyphen})"
                    f"([a-z0-9]*)$"
                )
            else:
                # Hyphenated pattern: abbr-region-env-workload[-role][-instance]
                pattern = (
                    f"^{re.escape(abbr)}"
                    f"-({region_pattern})"
                    f"-({env_pattern})"
                    f"-({workload_pattern})"
                    f"(-[a-z0-9]+)*$"
                )

            patterns[resource_type] = re.compile(pattern)

        return patterns

    def scan_resource_conf(self, conf):
        """Check that the resource name matches the naming convention."""
        name = conf.get("name")
        if name is None:
            return CheckResult.UNKNOWN

        if isinstance(name, list):
            name = name[0] if name else None
        if name is None:
            return CheckResult.UNKNOWN

        name = str(name).lower().strip()

        # Skip variable references
        if name.startswith("var.") or name.startswith("$") or name.startswith("local."):
            return CheckResult.UNKNOWN

        # Get the resource type from the check context
        resource_type = conf.get("resource_type", [""])[0] if isinstance(conf.get("resource_type"), list) else conf.get("resource_type", "")

        pattern = self.patterns.get(resource_type)
        if pattern is None:
            # No pattern defined for this resource type, skip
            return CheckResult.UNKNOWN

        if pattern.match(name):
            return CheckResult.PASSED

        return CheckResult.FAILED


check = NameMatchesStandard()
