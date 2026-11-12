# Branch Protection Rules for `main`

These rules should be configured in GitHub repository settings under
**Settings > Branches > Branch protection rules** for the `main` branch.

## Required Rules

### 1. Require Pull Request Before Merging
- Require at least **1 approval**
- Dismiss stale pull request approvals when new commits are pushed
- Require review from Code Owners (CODEOWNERS file)

### 2. Require Status Checks to Pass
- Require the **plan.yml** workflow to pass before merging
- Require branches to be up to date before merging

### 3. Require CODEOWNERS Approval
- Enabled via the "Require review from Code Owners" checkbox above
- Ensures the correct team reviews changes based on file paths:
  - `/requests/` changes require `cloud-coe` approval
  - `/.github/` changes require `platform-team` approval
  - `/bootstrap/` changes require `platform-leads` approval

### 4. Restrict Force Pushes
- **Do not allow force pushes** to `main`
- This prevents history rewriting and protects the audit trail

### 5. Restrict Deletions
- **Do not allow deletion** of the `main` branch

## Optional but Recommended

- Require signed commits (if your org uses commit signing)
- Require linear history (rebase merging only) for cleaner git log
- Restrict who can push to matching branches (limit to CI/CD bot)

## GitHub CLI Setup

```bash
# These can also be set via the GitHub API or gh CLI:
gh api repos/<GITHUB_ORG>/azure-deployments/branches/main/protection \
  --method PUT \
  --input - << 'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Terraform Plan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```
