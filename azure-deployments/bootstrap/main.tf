# =============================================================================
# Bootstrap: HCP Terraform + Azure OIDC Setup
# =============================================================================
#
# This configuration establishes the trust relationship between HCP Terraform
# (formerly Terraform Cloud) and Azure using OpenID Connect (OIDC).
#
# OIDC Trust Relationship:
# - HCP Terraform acts as the OIDC identity provider
# - Azure AD trusts tokens issued by HCP Terraform
# - When a Terraform run executes, HCP Terraform issues a JWT with claims
#   identifying the organization, project, and workspace
# - Azure AD validates the token and grants the corresponding service principal
#   access based on the federated identity credential's subject matching
#
# Wildcard Workspace Matching:
# - We use "organization:<org>:project:<project>:workspace:*" as the subject
# - This is because workspaces are created dynamically (one per request)
# - Each storage account, key vault, etc. gets its own workspace
# - Pinning to a specific workspace name would require updating credentials
#   every time a new request is created, which defeats self-service
# - The project-level scoping still provides security isolation between
#   prod and nonprod environments
# =============================================================================

locals {
  projects = toset(keys(var.subscriptions))

  # Flatten plan + apply identities for iteration
  identities = flatten([
    for project in local.projects : [
      {
        key     = "${project}-plan"
        project = project
        role    = "plan"
        display = "tfc-plan-${project}"
        az_role = "Reader"
      },
      {
        key     = "${project}-apply"
        project = project
        role    = "apply"
        display = "tfc-apply-${project}"
        az_role = "Contributor"
      }
    ]
  ])

  identity_map = { for id in local.identities : id.key => id }
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
# HCP Terraform: CI/CD Team (GitHub Actions service account)
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

# Grant the CI/CD team admin access on each project so it can create/manage
# workspaces and trigger runs.
resource "tfe_team_project_access" "cicd" {
  for_each   = tfe_project.this
  team_id    = tfe_team.cicd.id
  project_id = each.value.id
  access     = "admin"
}

# =============================================================================
# HCP Terraform: Variable Sets (per-project Azure credentials)
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
  description     = "Azure AD Tenant ID"
}

resource "tfe_variable" "arm_subscription_id" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_SUBSCRIPTION_ID"
  value           = var.subscriptions[each.key]
  category        = "env"
  variable_set_id = each.value.id
  description     = "Azure Subscription ID for ${each.key}"
}

resource "tfe_variable" "arm_use_oidc" {
  for_each        = tfe_variable_set.azure
  key             = "ARM_USE_OIDC"
  value           = "true"
  category        = "env"
  variable_set_id = each.value.id
  description     = "Enable OIDC authentication for Azure"
}

# The plan identity client ID is set per variable set so that plan-phase runs
# authenticate as the Reader-scoped service principal.
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
# Azure AD: Federated Identity Credentials (OIDC trust)
# =============================================================================
#
# Each federated identity credential tells Azure AD:
#   "When a token arrives from HCP Terraform's OIDC issuer, and the subject
#    claim matches this pattern, trust it and grant access as this app."
#
# The subject format for HCP Terraform is:
#   organization:<org>:project:<project>:workspace:<workspace>
#
# We use workspace:* (wildcard) because workspaces are created dynamically
# by the CI/CD pipeline for each infrastructure request. Without wildcards,
# we would need to create a new federated credential for every workspace,
# which would not scale for a self-service platform.

resource "azuread_application_federated_identity_credential" "this" {
  for_each = local.identity_map

  application_id = azuread_application.this[each.key].id
  display_name   = "tfc-oidc-${each.key}"
  description    = "HCP Terraform OIDC for ${each.value.role} phase in ${each.value.project}"

  audiences = ["api://AzureADTokenExchange"]
  issuer    = "https://app.terraform.io"

  # Wildcard workspace matching: allows any workspace within the project to
  # authenticate. This is essential for the self-service model where new
  # workspaces are created on-the-fly for each infrastructure request.
  subject = "organization:${var.tfc_org}:project:${each.value.project}:workspace:*"
}

# =============================================================================
# Azure RM: Role Assignments
# =============================================================================
#
# Plan identities get Reader -- they only need to read state and plan changes.
# Apply identities get Contributor -- they need to create/modify resources.

resource "azurerm_role_assignment" "this" {
  for_each = local.identity_map

  scope                = "/subscriptions/${var.subscriptions[each.value.project]}"
  role_definition_name = each.value.az_role
  principal_id         = azuread_service_principal.this[each.key].object_id
}
