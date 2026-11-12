#!/usr/bin/env bash
# =============================================================================
# check-naming-drift.sh
#
# Compares the workload, environment, and region lists in naming-rules.json
# against the workflow_dispatch options in request-storage.yml.
# Exits non-zero if they have drifted apart.
#
# Dependencies: jq, yq (https://github.com/mikefarah/yq)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMING_RULES="${REPO_ROOT}/terraform-modules/naming/data/naming-rules.json"
WORKFLOW="${REPO_ROOT}/azure-deployments/.github/workflows/request-storage.yml"

DRIFT_FOUND=0

# --- Helper ---
compare_lists() {
  local label="$1"
  local naming_list="$2"
  local workflow_list="$3"

  # Sort both lists for stable comparison
  naming_sorted=$(echo "$naming_list" | tr ' ' '\n' | sort)
  workflow_sorted=$(echo "$workflow_list" | tr ' ' '\n' | sort)

  if [[ "$naming_sorted" != "$workflow_sorted" ]]; then
    echo "DRIFT DETECTED in ${label}:"
    echo "  naming-rules.json : $(echo "$naming_sorted" | tr '\n' ' ')"
    echo "  request-storage.yml: $(echo "$workflow_sorted" | tr '\n' ' ')"

    # Show specific differences
    only_in_naming=$(comm -23 <(echo "$naming_sorted") <(echo "$workflow_sorted"))
    only_in_workflow=$(comm -13 <(echo "$naming_sorted") <(echo "$workflow_sorted"))

    if [[ -n "$only_in_naming" ]]; then
      echo "  In naming-rules.json but NOT in workflow: $only_in_naming"
    fi
    if [[ -n "$only_in_workflow" ]]; then
      echo "  In workflow but NOT in naming-rules.json: $only_in_workflow"
    fi
    echo ""
    DRIFT_FOUND=1
  else
    echo "OK: ${label} lists match."
  fi
}

# --- Validate dependencies ---
for cmd in jq yq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: ${cmd} is required but not installed." >&2
    exit 2
  fi
done

# --- Validate files exist ---
if [[ ! -f "$NAMING_RULES" ]]; then
  echo "ERROR: naming-rules.json not found at ${NAMING_RULES}" >&2
  exit 2
fi

if [[ ! -f "$WORKFLOW" ]]; then
  echo "ERROR: request-storage.yml not found at ${WORKFLOW}" >&2
  exit 2
fi

echo "Checking for drift between naming-rules.json and request-storage.yml..."
echo ""

# --- Extract from naming-rules.json ---
NAMING_WORKLOADS=$(jq -r '.workloads[]' "$NAMING_RULES")
NAMING_ENVIRONMENTS=$(jq -r '.environments[]' "$NAMING_RULES")
NAMING_REGIONS=$(jq -r '.region_codes | keys[]' "$NAMING_RULES")

# --- Extract from request-storage.yml ---
WORKFLOW_WORKLOADS=$(yq '.on.workflow_dispatch.inputs.workload.options[]' "$WORKFLOW")
WORKFLOW_ENVIRONMENTS=$(yq '.on.workflow_dispatch.inputs.environment.options[]' "$WORKFLOW")
WORKFLOW_REGIONS=$(yq '.on.workflow_dispatch.inputs.region.options[]' "$WORKFLOW")

# --- Compare ---
compare_lists "workloads" "$NAMING_WORKLOADS" "$WORKFLOW_WORKLOADS"
compare_lists "environments" "$NAMING_ENVIRONMENTS" "$WORKFLOW_ENVIRONMENTS"
compare_lists "regions" "$NAMING_REGIONS" "$WORKFLOW_REGIONS"

# --- Result ---
if [[ "$DRIFT_FOUND" -eq 1 ]]; then
  echo "FAILED: Naming drift detected. Update naming-rules.json or the workflow to match."
  exit 1
else
  echo "PASSED: No drift detected. All lists are in sync."
  exit 0
fi
