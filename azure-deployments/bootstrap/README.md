# Bootstrap

Creates the HCP Terraform and Azure infrastructure for the self-service platform.

## What it creates

### HCP Terraform
- **Projects**: `prod`, `nonprod`
- **Workspaces**: one per workload-environment (e.g. `sdwan-dev`, `sdwan-uat`, `sdwan-prod`)
  - API-driven execution, working directory `workloads/<workload>`
  - Terraform variable `environment` set per workspace
- **CI/CD team + token**: for GitHub Actions
- **Variable sets**: Azure OIDC credentials per project

### Azure AD
- **App registrations**: one plan + one apply identity per project
- **Federated credentials**: exact-match per workspace per phase (plan/apply)
  - Subject: `organization:<org>:project:<project>:workspace:<workspace>:run_phase:<phase>`
  - 20-per-app limit enforced by a check block

### Azure
- **Resource groups**: one per workload-environment, named `rg-<env>-<workload>`
- **Management locks**: CanNotDelete on prod resource groups
- **Role assignments**:
  - Plan identity: Reader at subscription scope
  - Apply identity: Contributor scoped to its project's resource groups only
- **Azure Policy** (deny effect):
  - Allowed regions
  - Required tags (one assignment per tag)
  - No public network access on storage accounts, Event Hub namespaces, Key Vaults

## Prerequisites

1. Azure CLI authenticated with Owner rights on the subscription
2. HCP Terraform org-level API token
3. Permissions to create Entra ID applications

## Run order

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values

terraform init
terraform plan
terraform apply
```

## After bootstrap

1. Set the `TFC_API_TOKEN` repo secret to the `cicd_team_token` output
2. Push `workloads/` to trigger the first plan

## Adding a workload

Add it to the `workloads` map in `terraform.tfvars` and re-apply bootstrap.
This creates the workspace, resource group, role assignments, and federated credentials.

## Federated credential limits

Each Entra ID application supports max 20 federated credentials.
The nonprod project covers dev, test, qa, uat, and nonprod environments,
so at most 20 workloads can share the nonprod plan or apply identity.

If this limit is reached:
1. **Split identities per workload** instead of per project
2. **Flexible federated identity credentials** (Entra Workload ID preview feature)
   — verify current availability and azuread provider support before adopting

## Consequences

- Adding a new resource group requires a bootstrap change by the platform team
- Deleting resources in a locked prod group requires Owner to remove the lock first
- Apply identities cannot modify resources outside their scoped resource groups
