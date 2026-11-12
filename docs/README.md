# Azure Self-Service Infrastructure Platform

## Overview

This platform enables teams to request Azure infrastructure through a self-service catalog backed by GitHub Actions, HCP Terraform (Terraform Cloud), and Azure OIDC. Engineers fill out a workflow form, a PR is created automatically, and after approval the infrastructure is provisioned via Terraform.

## Architecture

```
                            +---------------------+
                            |   Engineer / User    |
                            +----------+----------+
                                       |
                            1. workflow_dispatch
                                       |
                                       v
                         +-------------+-------------+
                         |  GitHub Actions Workflow   |
                         |  (request-storage.yml)     |
                         +-------------+-------------+
                                       |
                         2. Generates main.tf + tfvars
                            Creates PR on branch
                                       |
                                       v
                         +-------------+-------------+
                         |   Pull Request (PR)        |
                         |   CODEOWNERS review        |
                         +-------------+-------------+
                                       |
                         3. plan.yml triggers on PR
                            Runs Checkov policies
                            Runs terraform plan via TFC
                                       |
                                       v
                         +-------------+-------------+
                         |  HCP Terraform (OIDC)      |
                         |  plan workspace             |
                         +-------------+-------------+
                                       |
                         4. PR approved + merged
                                       |
                                       v
                         +-------------+-------------+
                         |  apply.yml triggers on      |
                         |  merge to main               |
                         +-------------+-------------+
                                       |
                         5. terraform apply via TFC
                            OIDC authenticates to Azure
                                       |
                                       v
                         +-------------+-------------+
                         |   Azure Subscription        |
                         |   (prod or nonprod)         |
                         +---------------------------+
```

## End-to-End Request Flow

1. **Engineer** navigates to GitHub Actions and runs a `workflow_dispatch` workflow (e.g., "Request: Storage Account")
2. **GitHub Actions** validates inputs, generates a resource name using the naming convention, scaffolds `main.tf` and `terraform.tfvars` into `requests/<name>/`
3. A **pull request** is created automatically on a feature branch
4. **plan.yml** triggers on the PR: runs Checkov custom policies, then creates/uses an HCP Terraform workspace and runs `terraform plan`
5. **CODEOWNERS** (cloud-coe team) reviews the PR and the plan output
6. On **merge to main**, `apply.yml` triggers and runs `terraform apply` via HCP Terraform
7. HCP Terraform authenticates to Azure via **OIDC** (no stored secrets) using federated identity credentials
8. The Azure resource is provisioned in the target subscription

## Directory Structure

```
terraform_cloud_azure/
+-- azure-deployments/              # Deployments repository
|   +-- .github/workflows/
|   |   +-- request-storage.yml     # Self-service: storage account request
|   |   +-- plan.yml                # Triggered on PR: plan + policy check
|   |   +-- apply.yml               # Triggered on merge: apply
|   |   +-- destroy.yml             # Manual: destroy a request
|   +-- bootstrap/                  # One-time setup (TFC + Azure OIDC)
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |   +-- versions.tf
|   |   +-- terraform.tfvars.example
|   +-- requests/                   # One directory per infrastructure request
|   |   +-- st-ncus-dev-sdwan/      # Example: storage account
|   |       +-- main.tf
|   |       +-- terraform.tfvars
|   +-- policies/                   # Checkov custom policies
|   |   +-- allowed_regions.py
|   |   +-- required_tags.py
|   |   +-- no_public_endpoints.py
|   |   +-- name_matches_standard.py
|   +-- CODEOWNERS
|   +-- BRANCH_PROTECTION.md
+-- terraform-modules/              # Shared Terraform modules
|   +-- naming/
|       +-- data/naming-rules.json  # Single source of truth for naming
+-- scripts/
|   +-- check-naming-drift.sh       # Detects drift between naming-rules + workflows
+-- docs/
    +-- README.md                   # This file
```

## Bootstrap Order

Run these steps once when setting up the platform for the first time.

### Step 1: Create HCP Terraform Organization
- Sign up at https://app.terraform.io
- Create an organization (this becomes `<TFC_ORG>`)
- Generate an organization-level API token

### Step 2: Create Azure Subscriptions
- Ensure `prod` and `nonprod` subscriptions exist
- Note their subscription IDs

### Step 3: Run Bootstrap Terraform
```bash
cd azure-deployments/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values
terraform init
terraform plan
terraform apply
```

This creates:
- HCP Terraform projects (prod, nonprod)
- CI/CD team + API token
- Azure AD apps with OIDC federated credentials
- Role assignments (Reader for plan, Contributor for apply)

### Step 4: Configure GitHub Secrets
Store the following as GitHub Actions repository secrets:

| Secret             | Source                                      |
|--------------------|---------------------------------------------|
| `TFC_API_TOKEN`    | `terraform output -raw cicd_team_token`     |

### Step 5: Configure Branch Protection
Follow the rules in `BRANCH_PROTECTION.md` to protect the `main` branch.

### Step 6: Publish Terraform Modules
Publish the `storage-account` module (and others) to the HCP Terraform private registry so that `app.terraform.io/<TFC_ORG>/storage-account/azurerm` resolves.

### Step 7: Test End-to-End
1. Run the "Request: Storage Account" workflow from the Actions tab
2. Verify the PR is created with correct naming
3. Verify `plan.yml` runs and shows a valid plan
4. Merge the PR and verify `apply.yml` provisions the resource

## Required Secrets

| Secret           | Where              | Purpose                              |
|------------------|--------------------|--------------------------------------|
| `TFC_API_TOKEN`  | GitHub Actions     | CI/CD team token for HCP Terraform   |

No Azure secrets are stored. Authentication uses OIDC federated identity credentials configured during bootstrap.

## Naming Standard

Resources follow the pattern: `<abbreviation>-<regioncode>-<env>-<workload>[-role][-instance]`

For resources that do not allow hyphens (e.g., storage accounts): `<abbreviation><regioncode><env><workload>[role][instance]`

Examples:
- `rg-ncus-dev-sdwan` (resource group)
- `stncusdevsdwan` (storage account)
- `kv-ncus-prod-core` (key vault)

The full mapping of abbreviations, region codes, environments, and workloads is defined in `terraform-modules/naming/data/naming-rules.json`.

## How to Add a New Catalog Item

To add a new self-service resource type (e.g., Key Vault):

1. **Create the Terraform module** in `terraform-modules/` (e.g., `terraform-modules/key-vault/`)
2. **Publish the module** to the HCP Terraform private registry
3. **Create a new workflow** in `.github/workflows/request-keyvault.yml`
   - Copy `request-storage.yml` as a template
   - Adjust the naming (abbreviation = `kv`, hyphens allowed)
   - Adjust the input fields for key-vault-specific settings
   - Update the generated `main.tf` to reference the new module
4. **Add Checkov policies** if the new resource type has specific security requirements
5. **Test** by running the new workflow and verifying end-to-end

## How to Add a New Workload or Region

1. **Edit `naming-rules.json`** to add the new workload or region entry
2. **Update all `workflow_dispatch` workflows** to include the new option in their dropdown lists
3. **Run the drift check** to verify consistency:
   ```bash
   ./scripts/check-naming-drift.sh
   ```
4. If the drift check passes, commit and push

## Placeholder List

The following placeholders must be replaced with real values before going live:

| Placeholder      | Description                              | Where Used                                                     |
|------------------|------------------------------------------|----------------------------------------------------------------|
| `<TFC_ORG>`      | HCP Terraform organization name          | bootstrap tfvars, request main.tf, workflows                   |
| `<GITHUB_ORG>`   | GitHub organization name                 | CODEOWNERS, BRANCH_PROTECTION.md, bootstrap tfvars             |
| `<TENANT_ID>`    | Azure AD Tenant ID                       | bootstrap tfvars, workflow-generated tfvars                    |
| `<SUB_ID>`       | Azure Subscription ID(s)                 | bootstrap tfvars, workflow-generated tfvars                    |

Search for these across the codebase:
```bash
grep -r "<TFC_ORG>\|<GITHUB_ORG>\|<TENANT_ID>\|<SUB_ID>" --include="*.tf" --include="*.yml" --include="*.md" --include="CODEOWNERS"
```
