# Bootstrap: HCP Terraform + Azure OIDC

This Terraform configuration bootstraps the foundational trust relationship between HCP Terraform and Azure. It is run once (or when adding new projects) and creates everything needed for the self-service platform to operate.

## What It Creates

- **HCP Terraform projects** for `prod` and `nonprod`
- **CI/CD team + token** for GitHub Actions to interact with HCP Terraform
- **Variable sets** with Azure OIDC credentials scoped to each project
- **Azure AD applications** with federated identity credentials (OIDC trust)
  - Plan identities (Reader role) for `terraform plan`
  - Apply identities (Contributor role) for `terraform apply`
- **Role assignments** on the target subscriptions

## Prerequisites

1. **Terraform >= 1.6.0** installed locally
2. **HCP Terraform organization** created with an API token that has organization-level access
3. **Azure AD permissions**: the identity running this bootstrap must be able to:
   - Create Azure AD applications and service principals
   - Create federated identity credentials
   - Assign roles on target subscriptions (Owner or User Access Administrator)
4. **Azure subscriptions** for prod and nonprod already created

## Run Order

```bash
# 1. Copy and fill in the variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values

# 2. Initialize
terraform init

# 3. Plan and review
terraform plan

# 4. Apply
terraform apply

# 5. Save the CI/CD team token as a GitHub Actions secret
terraform output -raw cicd_team_token
# Store this as TFC_API_TOKEN in your GitHub repo secrets

# 6. Note the apply client IDs - these are needed for the apply workflow
terraform output apply_client_ids
```

## After Bootstrap

- Set the `TFC_API_TOKEN` GitHub Actions secret from the team token output
- The plan workflow will automatically use the plan identity via OIDC
- The apply workflow needs the apply identity client ID (set in workflow or variable set)
- New workspaces are created dynamically -- the wildcard federated credential handles this
