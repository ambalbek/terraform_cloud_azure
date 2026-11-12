"""
Checkov custom policy: Allowed Azure Regions

Ensures that all azurerm resources are deployed only in regions defined
in the naming-rules.json region list. This prevents shadow deployments
in unapproved regions and keeps the naming standard consistent.
"""

import json
import os
from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class AllowedRegions(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Azure resources use only allowed regions"
        id = "CKV_AZURE_CUSTOM_001"
        supported_resources = ["azurerm_*"]
        categories = [CheckCategories.GENERAL_SECURITY]

        # Load allowed regions from naming-rules.json
        self.allowed_regions = self._load_allowed_regions()

        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def _load_allowed_regions(self):
        """Load the region list from naming-rules.json."""
        # Walk up from the policy directory to find naming-rules.json
        search_paths = [
            os.path.join(os.path.dirname(__file__), "..", "..", "terraform-modules", "naming", "data", "naming-rules.json"),
            os.path.join(os.path.dirname(__file__), "..", "..", "..", "terraform-modules", "naming", "data", "naming-rules.json"),
        ]

        for path in search_paths:
            abs_path = os.path.abspath(path)
            if os.path.exists(abs_path):
                with open(abs_path, "r") as f:
                    rules = json.load(f)
                return list(rules.get("region_codes", {}).keys())

        # Fallback: hardcoded list matching naming-rules.json
        return [
            "centralus",
            "canadacentral",
            "northcentralus",
            "southcentralus",
            "westeurope",
            "northeurope",
            "australiaeast",
            "australiasoutheast",
        ]

    def scan_resource_conf(self, conf):
        """Check that the resource's location is in the allowed list."""
        location = conf.get("location")

        if location is None:
            # Resources without a location attribute (e.g., sub-resources) pass
            return CheckResult.PASSED

        # Handle list values (Checkov sometimes wraps values in lists)
        if isinstance(location, list):
            location = location[0] if location else None

        if location is None:
            return CheckResult.PASSED

        # Normalize: lowercase and strip whitespace
        location = str(location).lower().strip()

        # Skip variable references and expressions -- they cannot be validated statically
        if location.startswith("var.") or location.startswith("$"):
            return CheckResult.UNKNOWN

        if location in self.allowed_regions:
            return CheckResult.PASSED

        return CheckResult.FAILED


check = AllowedRegions()
