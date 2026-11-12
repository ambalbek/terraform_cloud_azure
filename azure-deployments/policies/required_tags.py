"""
Checkov custom policy: Required Tags

Ensures that all taggable Azure resources include the mandatory tags:
environment, workload, owner, cost_center, and managed_by.
"""

from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


REQUIRED_TAGS = [
    "environment",
    "workload",
    "owner",
    "cost_center",
    "managed_by",
]

# Resources that support tags in Azure
TAGGABLE_RESOURCES = [
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


class RequiredTags(BaseResourceCheck):
    def __init__(self):
        name = "Ensure all taggable resources have required tags"
        id = "CKV_AZURE_CUSTOM_002"
        supported_resources = TAGGABLE_RESOURCES
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        """Check that all required tags are present."""
        tags = conf.get("tags")

        if tags is None:
            return CheckResult.FAILED

        # Handle list wrapper
        if isinstance(tags, list):
            tags = tags[0] if tags else {}

        if not isinstance(tags, dict):
            return CheckResult.UNKNOWN

        # Check each required tag exists and is not empty
        for tag in REQUIRED_TAGS:
            value = tags.get(tag)
            if value is None:
                return CheckResult.FAILED

            # Handle list wrapper on individual values
            if isinstance(value, list):
                value = value[0] if value else None

            if not value or (isinstance(value, str) and value.strip() == ""):
                return CheckResult.FAILED

        return CheckResult.PASSED


check = RequiredTags()
