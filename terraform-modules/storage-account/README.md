# Storage Account Module

Creates an Azure Storage Account with secure defaults and auto-generated naming.

## Overview

This module provisions an `azurerm_storage_account` resource. It delegates all name
generation to the shared **naming** module (`../naming`), so no `name` input variable
is accepted. The caller only provides workload, environment, location, and optional
role/instance identifiers.

## Secure Defaults

| Setting | Default |
|---|---|
| Public network access | Disabled |
| HTTPS only | Enabled |
| Minimum TLS version | 1.2 |
| Public blob access | Disabled |
| Blob versioning | Enabled |
| Blob soft delete | 30 days |
| Container soft delete | 30 days |

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `workload` | string | (required) | Workload or project name |
| `environment` | string | (required) | Environment code |
| `location` | string | (required) | Azure region |
| `role` | string | `null` | Optional role qualifier |
| `instance` | string | `null` | Optional two-digit instance number |
| `resource_group_name` | string | (required) | Target resource group |
| `account_tier` | string | `"Standard"` | Standard or Premium |
| `account_replication_type` | string | `"GRS"` | LRS, GRS, ZRS, or GZRS |
| `account_kind` | string | `"StorageV2"` | StorageV2 or BlobStorage |
| `access_tier` | string | `"Hot"` | Hot or Cool |
| `enable_versioning` | bool | `true` | Blob versioning |
| `enable_blob_soft_delete` | bool | `true` | Blob soft delete |
| `soft_delete_retention_days` | number | `30` | Blob soft delete retention (1-365) |
| `enable_container_delete_retention` | bool | `true` | Container soft delete |
| `container_delete_retention_days` | number | `30` | Container soft delete retention (1-365) |
| `enable_diagnostics` | bool | `false` | Send metrics to Log Analytics |
| `log_analytics_workspace_id` | string | `null` | Log Analytics workspace resource ID |
| `owner` | string | (required) | Owner tag |
| `cost_center` | string | (required) | Cost center tag |
| `tags` | map(string) | `{}` | Additional tags |

## Outputs

| Name | Description |
|---|---|
| `id` | Storage account resource ID |
| `name` | Storage account name |
| `primary_blob_endpoint` | Primary blob endpoint URL |
| `primary_connection_string` | Primary connection string (sensitive) |
| `generated_name` | Name produced by the naming module |
