# Azure Self-Service Infrastructure Platform

## Architecture Overview

This platform follows a **workload-per-workspace** model. Each workload (e.g., `sdwan`) has a single Terraform root module under `workloads/<workload>/`. That root module is deployed once per environment (`dev`, `prod`, etc.) via a dedicated HCP Terraform workspace. Resources within a workload are defined as map entries in environment-specific JSON files (e.g., `dev.json`, `prod.json`), and each resource type uses `for_each` over its map.

Key design principles:

- **One workspace per workload-environment pair** -- e.g., `sdwan-dev`, `sdwan-prod`.
- **No per-resource directories** -- adding a resource means adding a JSON map entry, not a new Terraform root.
- **Catalog-driven** -- resource type schemas are defined in `catalog/<type>.json`; workflows read these schemas.
- **OIDC everywhere** -- no stored Azure credentials. HCP Terraform authenticates to Azure via federated identity credentials configured during bootstrap.

## End-to-End Request Flow

1. **Engineer** navigates to GitHub Actions and runs a `workflow_dispatch` form (e.g., "Request: Event Hub").
2. **`_request.yml`** (reusable workflow) validates inputs and uses `jq` to merge the new resource entry into the workload's `<env>.json` file.
3. A **pull request** is created automatically on a feature branch.
4. **`plan.yml`** triggers on the PR: runs Checkov custom policies (e.g., `no_public_endpoints.py`), then executes `terraform plan` via HCP Terraform.
5. **CODEOWNERS** (cloud-coe team) reviews the PR and the plan output.
6. If the plan contains **destroy actions**, the PR must carry the `allow-destroy` label before merge is permitted.
7. On **merge to main**, `apply.yml` triggers and runs `terraform apply` via HCP Terraform.
8. HCP Terraform authenticates to Azure via **OIDC** and provisions (or updates/destroys) the resource.

## Directory Structure

```
terraform_cloud_azure/
+-- .github/workflows/
|   +-- _request.yml            # Reusable: jq-merge into JSON, create PR
|   +-- request-eventhub.yml    # Self-service form: Event Hub
|   +-- plan.yml                # Triggered on PR: checkov + terraform plan
|   +-- apply.yml               # Triggered on merge: terraform apply
|   +-- drift.yml               # Scheduled: detect config drift
+-- azure-deployments/
|   +-- bootstrap/              # One-time setup (TFC orgs, Azure AD apps, OIDC)
|   |   +-- main.tf
|   |   +-- variables.tf
|   |   +-- outputs.tf
|   |   +-- versions.tf
|   |   +-- terraform.tfvars.example
|   +-- policies/               # Checkov custom policies
|   |   +-- no_public_endpoints.py
|   +-- CODEOWNERS
|   +-- BRANCH_PROTECTION.md
+-- catalog/                    # Resource type schemas (one JSON per type)
|   +-- eventhub_namespace.json
|   +-- storage_account.json
+-- workloads/                  # One directory per workload
|   +-- sdwan/
|       +-- main.tf             # Root module (for_each over each resource type)
|       +-- variables.tf
|       +-- versions.tf
|       +-- dev.json            # Dev environment resource map
|       +-- prod.json           # Prod environment resource map
|       +-- uat.json            # UAT environment resource map
+-- terraform-modules/          # Shared Terraform modules
|   +-- naming/
|       +-- data/naming-rules.json  # Single source of truth for naming
|       +-- main.tf
|       +-- variables.tf
|       +-- outputs.tf
|       +-- tests/naming.tftest.hcl
+-- scripts/
|   +-- check-naming-drift.sh   # Detects drift between naming-rules + workflows
+-- docs/
    +-- README.md               # This file
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

- HCP Terraform projects (one per environment)
- CI/CD team and API token
- Azure AD applications with OIDC federated credentials (plan = Reader, apply = Contributor)
- Resource groups for each workload-environment pair
- CanNotDelete management locks on prod resource groups
- Azure Policy assignments for allowed regions and required tags

### Step 4: Configure GitHub Secrets

Store the following as GitHub Actions repository secrets:

| Secret          | Source                                  |
|-----------------|-----------------------------------------|
| `TFC_API_TOKEN` | `terraform output -raw cicd_team_token` |

### Step 5: Configure Branch Protection

Follow the rules in `azure-deployments/BRANCH_PROTECTION.md` to protect the `main` branch.

### Step 6: Publish Terraform Modules

Publish shared modules to the HCP Terraform private registry so that sources like `app.terraform.io/<TFC_ORG>/naming/azurerm` resolve.

### Step 7: Test End-to-End

1. Run "Request: Event Hub" from the Actions tab
2. Verify the PR is created with correct JSON merge
3. Verify `plan.yml` runs and shows a valid plan
4. Merge the PR and verify `apply.yml` provisions the resource

## Required Secrets

| Secret          | Where          | Purpose                            |
|-----------------|----------------|------------------------------------|
| `TFC_API_TOKEN` | GitHub Actions | CI/CD team token for HCP Terraform |

No Azure secrets are stored. Authentication uses OIDC federated identity credentials configured during bootstrap.

## Naming Standard

Resources follow the pattern:

```
<abbreviation>-<regioncode>-<env>-<workload>[-role][-instance]
```

For resources that do not allow hyphens (e.g., storage accounts):

```
<abbreviation><regioncode><env><workload>[role][instance]
```

The full mapping of abbreviations, region codes, environments, and workloads is defined in `terraform-modules/naming/data/naming-rules.json`. This file is the single source of truth. The `scripts/check-naming-drift.sh` script verifies that workflow dropdown options stay in sync with `naming-rules.json`.

Examples:

- `evhns-ncus-dev-sdwan-db-01` (Event Hub Namespace, role=db, instance=01)
- `evhns-cus-dev-sdwan` (Event Hub Namespace, no role/instance)
- `stncusprodsdwan` (storage account, no hyphens)
- `rg-ncus-prod-sdwan` (resource group)

## How to Onboard a New Workload

1. **Create a workload directory**: `workloads/<workload-name>/`
2. **Write `main.tf`**: define `for_each` blocks for each resource type, calling the naming module and the resource module. Use `workloads/sdwan/main.tf` as a template.
3. **Write `variables.tf`** and `versions.tf`** (copy from sdwan).
4. **Create environment JSON files**: `dev.json`, `prod.json`, etc. Start with empty maps (`{}`).
5. **Update bootstrap** to create resource groups and TFC workspaces for the new workload.
6. **Add the workload name** to `naming-rules.json` in the `workloads` array.
7. **Update workflow dropdowns** (all `request-*.yml` files) to include the new workload.
8. **Run `scripts/check-naming-drift.sh`** to verify no drift.

## How to Add a New Catalog Item

Adding a new self-service resource type (e.g., Key Vault) requires three things:

1. **Create `catalog/<type>.json`** -- define the schema (parameters, defaults) for the new resource type.
2. **Create `.github/workflows/request-<type>.yml`** -- a workflow_dispatch form that collects inputs and calls `_request.yml`. Copy `request-eventhub.yml` as a template.
3. **Add a `for_each` block** in each workload's `main.tf` that should support the resource type. The block reads `local.values.<type_map>`, calls the naming module, and calls the resource module.

## How Removal Works

1. **Delete the map entry** from the workload's `<env>.json` file (or submit via a workflow that does this).
2. **Open a PR**. `plan.yml` runs and the plan shows a destroy action.
3. **Add the `allow-destroy` label** to the PR. Without this label, the merge check blocks.
4. **Merge the PR**. `apply.yml` runs `terraform apply`, which destroys the resource.

The `allow-destroy` label is a safety gate: reviewers must explicitly acknowledge that resources will be deleted. The label requirement is enforced by the plan workflow's status check.

## Drift Detection

The `drift.yml` workflow runs on a cron schedule. It executes `terraform plan` for each workspace and reports any differences between the Terraform state and the actual Azure resources. If drift is detected, the workflow opens an issue or posts to the configured notification channel.

Naming drift (workflow dropdowns vs. `naming-rules.json`) is checked separately by `scripts/check-naming-drift.sh`, which can be run locally or in CI.

## Federated Credential Limits

Azure AD applications have a limit of **20 federated identity credentials** per application. Each TFC workspace requires one federated credential (for OIDC). The bootstrap module creates separate Azure AD apps for plan and apply, so you get 20 plan workspaces and 20 apply workspaces per app. If you exceed this limit, the bootstrap module must be extended to create additional Azure AD apps.

Plan accordingly: with 10 workloads x 3 environments = 30 workspaces, you will need at least 2 Azure AD apps per role (plan/apply).

## Consequences and Guardrails

- **Resource groups are a bootstrap change**. Adding or removing an RG requires updating the bootstrap Terraform and running `terraform apply` there. Workload-level Terraform cannot create or destroy resource groups.
- **Prod management locks require Owner role to remove**. The CanNotDelete locks on prod resource groups mean that even a Contributor-level apply cannot accidentally destroy the RG or its children. An Owner must explicitly remove the lock first.
- **`prevent_destroy` cannot be used with `for_each` modules**. See the comment block in `workloads/sdwan/main.tf` for details. Protection is provided instead by management locks (prod) and the allow-destroy workflow guard (all environments).
- **Azure Policy enforces allowed regions and required tags** at the subscription level (configured in bootstrap). This replaces the old Checkov policies `allowed_regions.py` and `required_tags.py`.

## Placeholder List

The following placeholders must be replaced with real values before going live:

| Placeholder    | Description                     | Where Used                                              |
|----------------|---------------------------------|---------------------------------------------------------|
| `<TFC_ORG>`    | HCP Terraform organization name | bootstrap tfvars, workload main.tf, workflows           |
| `<GITHUB_ORG>` | GitHub organization name        | CODEOWNERS, BRANCH_PROTECTION.md, bootstrap tfvars      |
| `<TENANT_ID>`  | Azure AD Tenant ID              | bootstrap tfvars                                        |
| `<SUB_ID>`     | Azure Subscription ID(s)        | bootstrap tfvars                                        |

Search for these across the codebase:

```bash
grep -r "<TFC_ORG>\|<GITHUB_ORG>\|<TENANT_ID>\|<SUB_ID>" \
  --include="*.tf" --include="*.yml" --include="*.md" --include="CODEOWNERS"
```
