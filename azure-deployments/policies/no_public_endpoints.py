"""
Checkov custom policy: No Public Endpoints on Storage Accounts

Ensures that storage accounts are configured securely:
- public_network_access_enabled = false
- https_traffic_only_enabled = true
- min_tls_version = "TLS1_2"
"""

from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class NoPublicEndpoints(BaseResourceCheck):
    def __init__(self):
        name = "Ensure storage accounts have no public endpoints and enforce TLS 1.2"
        id = "CKV_AZURE_CUSTOM_003"
        supported_resources = ["azurerm_storage_account"]
        categories = [CheckCategories.NETWORKING]
        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def _get_value(self, conf, key, default=None):
        """Extract a config value, handling Checkov's list wrapping."""
        value = conf.get(key, default)
        if isinstance(value, list):
            value = value[0] if value else default
        return value

    def scan_resource_conf(self, conf):
        """Check storage account security settings."""

        # 1. public_network_access_enabled must be false
        public_access = self._get_value(conf, "public_network_access_enabled")
        if public_access is None or public_access is True or str(public_access).lower() == "true":
            return CheckResult.FAILED

        # 2. https_traffic_only_enabled must be true
        https_only = self._get_value(conf, "https_traffic_only_enabled")
        # Default is true in Azure, but we require it to be explicitly set
        if https_only is not None and (https_only is False or str(https_only).lower() == "false"):
            return CheckResult.FAILED

        # 3. min_tls_version must be TLS1_2
        tls_version = self._get_value(conf, "min_tls_version", "TLS1_2")
        if isinstance(tls_version, str) and tls_version not in ("TLS1_2",):
            return CheckResult.FAILED

        return CheckResult.PASSED


check = NoPublicEndpoints()
