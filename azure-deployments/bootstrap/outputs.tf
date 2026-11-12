output "project_ids" {
  description = "Map of project name to HCP Terraform project ID"
  value       = { for k, v in tfe_project.this : k => v.id }
}

output "cicd_team_token" {
  description = "API token for the CI/CD team (GitHub Actions service account)"
  value       = tfe_team_token.cicd.token
  sensitive   = true
}

output "plan_client_ids" {
  description = "Map of project name to Azure AD plan identity client ID (Reader role)"
  value = {
    for k, v in azuread_application.this : trimprefix(k, "") => v.client_id
    if endswith(k, "-plan")
  }
}

output "apply_client_ids" {
  description = "Map of project name to Azure AD apply identity client ID (Contributor role)"
  value = {
    for k, v in azuread_application.this : trimprefix(k, "") => v.client_id
    if endswith(k, "-apply")
  }
}

output "variable_set_ids" {
  description = "Map of project name to Azure OIDC variable set ID"
  value       = { for k, v in tfe_variable_set.azure : k => v.id }
}
