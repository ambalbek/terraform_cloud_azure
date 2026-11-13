output "project_ids" {
  description = "Map of project name to HCP Terraform project ID."
  value       = { for k, v in tfe_project.this : k => v.id }
}

output "workspace_ids" {
  description = "Map of workspace name to HCP Terraform workspace ID."
  value       = { for k, v in tfe_workspace.this : k => v.id }
}

output "cicd_team_token" {
  description = "API token for the CI/CD team (GitHub Actions)."
  value       = tfe_team_token.cicd.token
  sensitive   = true
}

output "plan_client_ids" {
  description = "Map of project name to plan identity client ID."
  value = {
    for k, v in local.identity_map : v.project => azuread_application.this[k].client_id
    if v.phase == "plan"
  }
}

output "apply_client_ids" {
  description = "Map of project name to apply identity client ID."
  value = {
    for k, v in local.identity_map : v.project => azuread_application.this[k].client_id
    if v.phase == "apply"
  }
}

output "resource_group_ids" {
  description = "Map of workspace name to resource group ID."
  value       = { for k, v in azurerm_resource_group.this : k => v.id }
}

output "resource_group_names" {
  description = "Map of workspace name to resource group name."
  value       = { for k, v in azurerm_resource_group.this : k => v.name }
}

output "fed_cred_count" {
  description = "Federated credential count per application (max 20)."
  value       = local.fed_creds_per_app
}
