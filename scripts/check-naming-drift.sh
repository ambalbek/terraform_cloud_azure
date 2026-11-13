#!/usr/bin/env bash
# =============================================================================
# check-naming-drift.sh
#
# Compares the workload and environment lists in naming-rules.json against the
# workflow_dispatch options in every request-*.yml workflow file.
# Exits non-zero if they have drifted apart.
#
# Note: Regions are not checked because region lists come from AVM (Azure
# Verified Modules) and are intentionally broader than naming-rules.json.
#
# Dependencies: jq, yq (https://github.com/mikefarah/yq)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NAMING_RULES="${REPO_ROOT}/terraform-modules/naming/data/naming-rules.json"
WORKFLOW_DIR="${REPO_ROOT}/.github/workflows"

DRIFT_FOUND=0

# --- Helper ---
compare_lists() {
  local label="$1"
  local workflow_file="$2"
  local naming_list="$3"
  local workflow_list="$4"

  # Sort both lists for stable comparison
  naming_sorted=$(echo "$naming_list" | tr ' ' '\n' | sort)
  workflow_sorted=$(echo "$workflow_list" | tr ' ' '\n' | sort)

  if [[ "$naming_sorted" != "$workflow_sorted" ]]; then
    echo "DRIFT DETECTED in ${label} ($(basename "$workflow_file")):"
    echo "  naming-rules.json: $(echo "$naming_sorted" | tr '\n' ' ')"
    echo "  workflow:          $(echo "$workflow_sorted" | tr '\n' ' ')"

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
    echo "OK: ${label} in $(basename "$workflow_file") matches."
  fi
}

# --- Validate dependencies ---
for cmd in jq yq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: ${cmd} is required but not installed." >&2
    exit 2
  fi
done

# --- Validate naming-rules.json exists ---
if [[ ! -f "$NAMING_RULES" ]]; then
  echo "ERROR: naming-rules.json not found at ${NAMING_RULES}" >&2
  exit 2
fi

# --- Find all request-*.yml workflow files ---
shopt -s nullglob
WORKFLOW_FILES=("${WORKFLOW_DIR}"/request-*.yml)
shopt -u nullglob

if [[ ${#WORKFLOW_FILES[@]} -eq 0 ]]; then
  echo "ERROR: No request-*.yml files found in ${WORKFLOW_DIR}" >&2
  exit 2
fi

echo "Checking for naming drift..."
echo "  naming-rules.json: ${NAMING_RULES}"
echo "  Workflow files:    ${#WORKFLOW_FILES[@]} found"
echo ""

# --- Extract from naming-rules.json ---
NAMING_WORKLOADS=$(jq -r '.workloads[]' "$NAMING_RULES")
NAMING_ENVIRONMENTS=$(jq -r '.environments[]' "$NAMING_RULES")

# --- Check each workflow file ---
for wf in "${WORKFLOW_FILES[@]}"; do
  # Extract workload options (if the input exists)
  WF_WORKLOADS=$(yq '.on.workflow_dispatch.inputs.workload.options[]' "$wf" 2>/dev/null || true)
  WF_ENVIRONMENTS=$(yq '.on.workflow_dispatch.inputs.environment.options[]' "$wf" 2>/dev/null || true)

  if [[ -n "$WF_WORKLOADS" ]]; then
    compare_lists "workloads" "$wf" "$NAMING_WORKLOADS" "$WF_WORKLOADS"
  fi

  if [[ -n "$WF_ENVIRONMENTS" ]]; then
    compare_lists "environments" "$wf" "$NAMING_ENVIRONMENTS" "$WF_ENVIRONMENTS"
  fi
done

# --- Result ---
if [[ "$DRIFT_FOUND" -eq 1 ]]; then
  echo "FAILED: Naming drift detected. Update naming-rules.json or the workflow(s) to match."
  exit 1
else
  echo "PASSED: No drift detected. All lists are in sync."
  exit 0
fi
