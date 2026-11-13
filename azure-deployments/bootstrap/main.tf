# =============================================================================
# Bootstrap: HCP Terraform workspaces, Azure OIDC, resource groups, policies
# =============================================================================
#
# One workspace per workload-environment pair.
# Exact-match federated credentials per workspace per phase (plan/apply).
# Resource groups created here, scoped role assignments on them.
# Azure Policy for allowed regions, required tags, no public endpoints.
# =============================================================================

locals {
  # Flatten workloads × environments into workspace entries
  workspace_entries = flatten([
    for wl, envs in var.workloads : [
      for env in envs : {
        workload    = wl
        environment = env
        workspace   = "${wl}-${env}"
        project     = env == "prod" ? "prod" : "nonprod"
      }
    ]
  ])

  workspace_map = { for ws in local.workspace_entries : ws.workspace => ws }

  # Unique projects
  projects = toset(distinct([for ws in local.workspace_entries : ws.project]))

  # Federated identity entries: one per workspace per phase (plan/apply)
  fed_cred_entries = flatten([
    for ws_key, ws in local.workspace_map : [
      {
        key       = "${ws_key}-plan"
        workspace = ws_key
        project   = ws.project
        phase     = "plan"
        app_key   = "${ws.project}-plan"
      },
      {
        key       = "${ws_key}-apply"
        workspace = ws_key
        project   = ws.project
        phase     = "apply"
        app_key   = "${ws.project}-apply"
      }
    ]
  ])

  fed_cred_map = { for fc in local.fed_cred_entries : fc.key => fc }

  # Identity apps: one per project per phase
  identity_entries = flatten([
    for project in local.projects : [
      {
        key     = "${project}-plan"
        project = project
        phase   = "plan"
        display = "tfc-plan-${project}"
        az_role = "Reader"
      },
      {
        key     = "${project}-apply"
        project = project
        phase   = "apply"
        display = "tfc-apply-${project}"
        az_role = "Contributor"
      }
    ]
  ])

  identity_map = { for id in local.identity_entries : id.key => id }

  # Count federated credentials per app to enforce the 20-per-app limit
  fed_creds_per_app = {
    for app_key in keys(local.identity_map) : app_key => length([
      for fc in local.fed_cred_entries : fc if fc.app_key == app_key
    ])
  }

  # Resource groups: one per workload-environment, named by convention
  # rg-<region_code>-<env>-<workload>
  # Region comes from the first allowed region (platform default).
  # Override per workload-env if needed via a future variable.
  rg_entries = {
    for ws_key, ws in local.workspace_map : ws_key => {
      workload    = ws.workload
      environment = ws.environment
      project     = ws.project
      workspace   = ws.workspace
    }
  }
}

# =============================================================================
# Guard: federated credential limit (20 per application)
# =============================================================================

check "fed_cred_limit" {
  assert {
    condition = alltrue([
      for app_key, count in local.fed_creds_per_app : count <= 20
    ])
    error_message = <<-EOT
      Federated credential limit exceeded (max 20 per application).
      Counts: ${jsonencode(local.fed_creds_per_app)}

      Options to resolve:
      1. Split into one identity pair per workload (instead of per project).
      2. Use Entra Workload ID flexible federated identity credentials
         (preview feature, verify current availability and Terraform support
         before adopting — requires microsoft.graph provider or azapi).
    EOT
  }
}

# =============================================================================
# HCP Terraform: Projects
# =============================================================================

resource "tfe_project" "this" {
  for_each     = local.projects
  organization = var.tfc_org
  name         = each.key
}

# =============================================================================
# HCP Terraform: CI/CD Team
# =============================================================================

resource "tfe_team" "cicd" {
  organization = var.tfc_org
  name         = "cicd-github-actions"

  organization_access {
    manage_workspaces = true
    manage_projects   = false
    manage_policies   = false
  }
}

resource "tfe_team_token" "cicd" {
  team_id = tfe_team.cicd.id
}

resource "tfe_team_project_access" "cicd" {
  for_each   = tfe_project.this
  team_id    = tfe_team.cicd.id
  project_id = each.value.id
  access     = "admin"
}

# =============================================================================
# HCP Terraform: Workspaces (one per workload-environment)
# =============================================================================

resource "tfe_workspace" "this" {
  for_each     = local.workspace_map
  organization = var.tfc_org
  name         = each.key
  project_id   = tfe_project.this[each.value.project].id

  auto_apply        = false
  working_directory = "workloads/${each.value.workload}"

  tag_names = [each.value.workload, each.value.environment, each.value.project]
}

resource "tfe_workspace_settings" "this" {
  for_each       = tfe_workspace.this
  workspace_id   = each.value.id
  execution_mode = "remote"
}

resource "tfe_variable" "environment" {
  for_each     = tfe_workspace.this
  key          = "environment"
  value        = local.workspace_map[each.key].environment
  category     = "terraform"
  workspace_id = each.value.id
  description  = "Environment for this workspace"
}

# =============================================================================
# HCP Terraform: Variable Sets (per-project Azure OIDC credentials)
# =============================================================================

resource "tfe_variable_set" "azure" {
  for_each     = local.projects
  organization = var.tfc_org
  name         = "azure-oidc-${each.key}"
  description  = "Azure OIDC credentials for ${each.key} project"
}

resource "tfe_project_variable_set" "azure" {
  for_each        = tfe_variable_set.azure
  variable_set_id = each.value.id
  project_id      = tfe_project.this[each.key].id
}

resource "tfe_variable" "arm_tenant_id" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_TENANT_ID"
  value           = var.tenant_id
  category        = "env"
  variable_set_id = each.value.id
}

resource "tfe_variable" "arm_subscription_id" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_SUBSCRIPTION_ID"
  value           = var.subscription_id
  category        = "env"
  variable_set_id = each.value.id
}

resource "tfe_variable" "arm_use_oidc" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_USE_OIDC"
  value           = "true"
  category        = "env"
  variable_set_id = each.value.id
}

resource "tfe_variable" "arm_client_id_plan" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_CLIENT_ID"
  value           = azuread_application.this["${each.key}-plan"].client_id
  category        = "env"
  variable_set_id = each.value.id
  description     = "Plan identity client ID (Reader role)"
}

# =============================================================================
# Azure AD: Application Registrations + Service Principals
# =============================================================================

resource "azuread_application" "this" {
  for_each     = local.identity_map
  display_name = each.value.display
}

resource "azuread_service_principal" "this" {
  for_each  = azuread_application.this
  client_id = each.value.client_id
}

# =============================================================================
# Azure AD: Federated Identity Credentials (exact match per workspace)
# =============================================================================
#
# Standard Entra federated identity credentials require an exact string match
# on the subject claim. Wildcards are NOT supported (verified against
# Microsoft docs: "The subject ... must be an exact case-sensitive match").
#
# With one workspace per workload-env, we have a known, fixed set of
# workspaces. Each gets a plan and apply credential on the appropriate app.
#
# HCP Terraform subject format:
#   organization:<org>:project:<project>:workspace:<workspace>:run_phase:<phase>
#
# The per-application limit is 20 federated credentials. With the nonprod
# project covering dev, test, qa, uat and nonprod environments, that allows
# up to 20 workloads per project per phase. A check block above fails if
# this limit would be exceeded.
#
# If 20 is not enough, two options exist:
# 1. Split into one identity pair per workload instead of per project.
# 2. Use Entra Workload ID "flexible federated identity credentials" (which
#    support claim customization and wildcard-like matching). As of late 2025
#    this feature is in public preview and not supported by the azuread
#    Terraform provider. Track: https://github.com/hashicorp/terraform-provider-azuread/issues
#    and use the azapi provider as a workaround if needed.

resource "azuread_application_federated_identity_credential" "this" {
  for_each = local.fed_cred_map

  application_id = azuread_application.this[each.value.app_key].id
  display_name   = "tfc-${each.key}"
  description    = "HCP Terraform OIDC: ${each.value.phase} phase, workspace ${each.value.workspace}"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://app.terraform.io"

  subject = "organization:${var.tfc_org}:project:${each.value.project}:workspace:${each.value.workspace}:run_phase:${each.value.phase}"
}

# =============================================================================
# Azure RM: Resource Groups (one per workload-environment)
# =============================================================================
#
# Resource groups are created by bootstrap, not by workload Terraform.
# Workloads look them up with data sources and reference by key.
# This ensures role assignments can be scoped before workload runs.
#
# Consequence: adding a new resource group is a bootstrap change by the
# platform team, not a developer self-service action.

resource "azurerm_resource_group" "this" {
  for_each = local.rg_entries

  name     = "rg-${each.value.environment}-${each.value.workload}"
  location = var.allowed_regions[0]

  tags = {
    environment = each.value.environment
    workload    = each.value.workload
    managed_by  = "terraform-bootstrap"
  }
}

# =============================================================================
# Azure RM: Management Locks (CanNotDelete on prod resource groups)
# =============================================================================
#
# Deleting anything in a locked prod group requires someone with Owner
# rights to remove the lock first. This is intentional.

resource "azurerm_management_lock" "prod" {
  for_each = {
    for k, v in local.rg_entries : k => v if v.environment == "prod"
  }

  name       = "CanNotDelete-${each.key}"
  scope      = azurerm_resource_group.this[each.key].id
  lock_level = "CanNotDelete"
  notes      = "Prod resource group — removal requires Owner to delete lock first"
}

# =============================================================================
# Azure RM: Role Assignments
# =============================================================================
#
# Plan identity: Reader at subscription scope (acceptable for plan).
# Apply identity: Contributor scoped to its own project's resource groups only.
#   This means a nonprod apply identity cannot modify prod resources.
#
# Note: the apply identity has Contributor on each RG of its project, which
# is sufficient to create/modify resources within those groups. It cannot
# create new resource groups (that's a bootstrap action).

# Plan: subscription-scoped Reader (one per project)
resource "azurerm_role_assignment" "plan" {
  for_each = {
    for k, v in local.identity_map : k => v if v.phase == "plan"
  }

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.this[each.key].object_id
}

# Apply: RG-scoped Contributor (one assignment per RG per project's apply identity)
locals {
  apply_rg_assignments = flatten([
    for rg_key, rg in local.rg_entries : {
      key          = "${rg.project}-apply-${rg_key}"
      rg_key       = rg_key
      identity_key = "${rg.project}-apply"
    }
  ])

  apply_rg_assignment_map = { for a in local.apply_rg_assignments : a.key => a }
}

resource "azurerm_role_assignment" "apply" {
  for_each = local.apply_rg_assignment_map

  scope                = azurerm_resource_group.this[each.value.rg_key].id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.this[each.value.identity_key].object_id
}

# =============================================================================
# Azure Policy: Allowed Regions (deny effect)
# =============================================================================

resource "azurerm_subscription_policy_assignment" "allowed_regions" {
  name                 = "allowed-regions"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"
  display_name         = "Allowed locations"
  description          = "Restrict resource deployment to approved regions."
  enforce              = true

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_regions
    }
  })
}

# =============================================================================
# Azure Policy: Required Tags (deny effect, one per tag)
# =============================================================================

resource "azurerm_subscription_policy_assignment" "required_tags" {
  for_each = var.required_tags

  name                 = "require-tag-${each.key}"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b466-571e8ab1a0c3"
  display_name         = "Require tag: ${each.key}"
  description          = each.value
  enforce              = true

  parameters = jsonencode({
    tagName = {
      value = each.key
    }
  })
}

# =============================================================================
# Azure Policy: Deny Public Network Access (per catalog resource type)
# =============================================================================
#
# Storage accounts: deny public blob access
resource "azurerm_subscription_policy_assignment" "deny_public_storage" {
  name                 = "deny-public-storage"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/b2982f36-99f2-4db5-8eff-283140c09693"
  display_name         = "Storage accounts should disable public network access"
  enforce              = true
}

# Event Hub namespaces: deny public network access
resource "azurerm_subscription_policy_assignment" "deny_public_eventhub" {
  name                 = "deny-public-eventhub"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0602787f-9896-402a-a6e1-39ee63ee435e"
  display_name         = "Event Hub namespaces should disable public network access"
  enforce              = true
}

# Key Vault: deny public network access
resource "azurerm_subscription_policy_assignment" "deny_public_keyvault" {
  name                 = "deny-public-keyvault"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b"
  display_name         = "Key Vaults should disable public network access"
  enforce              = true
}
