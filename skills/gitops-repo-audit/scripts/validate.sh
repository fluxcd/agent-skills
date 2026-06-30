#!/usr/bin/env bash

# Copyright 2023-2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script validates the Flux custom resources and the kustomize
# overlays using flux-schema against its built-in catalog of Kubernetes
# and Flux API schemas, evaluating both JSON Schema and CEL rules.

# Prerequisites
# - kustomize, or kubectl (uses its embedded kustomize via 'kubectl kustomize')
# - flux-schema, available either as a standalone binary on PATH or as a plugin
#   (install with: flux plugin install schema)
# - network access to the flux-schema catalog, which '--schema-location default'
#   fetches from https://raw.githubusercontent.com/fluxcd/flux-schema/main/catalog
#   (without it, resources fail with "schema load error" rather than validating)

set -o pipefail

# track validation results across every flux-schema invocation:
# - invalid/skipped/valid are summed per resource (parsed from each Summary line)
# - build_errors counts kustomize overlays that failed to build
# - tool_errors counts flux-schema runs that failed without producing a Summary
#   (bad flag, plugin/runtime error, catalog fetch failure) — these must not be
#   reported as success
total_valid=0
total_invalid=0
total_skipped=0
build_errors=0
tool_errors=0

# set by accumulate() to 1 when the last run produced a Summary line
last_run_had_summary=0

# mirror kustomize-controller build options
kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
kustomize_config="kustomization.yaml"

# flux-schema validation options:
# - validate against the built-in catalog of stable Kubernetes and Flux APIs
# - skip documents without a schema (third-party CRDs) instead of failing
# - strip SOPS metadata so encrypted Secrets validate without decryption
# - pin text output so the Summary-line parsing in accumulate() is not broken by
#   an ambient config (FLUX_SCHEMA_CONFIG or an <executable>.config) flipping it
flux_schema_flags=(
  "--schema-location" "default"
  "--skip-missing-schemas"
  "--skip-json-path" "v1/Secret:/sops"
  "--output" "text"
)

# commands resolved by check_prerequisites: how to invoke kustomize and flux-schema
kustomize_cmd=()
flux_schema=()

# root directory to validate
root_dir="."

# basename glob patterns for directories to exclude from validation
# (matched against each path component, mirroring 'flux schema discover --skip-file')
exclude_dirs=()

# directories auto-detected as non-Kubernetes (terraform, helm charts)
declare -A auto_skip_dirs=()

# directories that are kustomize overlays
declare -A kustomize_dirs=()

usage() {
  echo "Usage: $0 [-d <dir>] [-e <dir>]... [-h]"
  echo ""
  echo "Validate Flux custom resources and kustomize overlays using flux-schema."
  echo ""
  echo "Options:"
  echo "  -d, --dir <dir>       Root directory to validate (default: current directory)"
  echo "  -e, --exclude <name>  Directory name to exclude (basename glob, can be repeated)"
  echo "  -h, --help            Show this help message"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dir)
        if [[ -z "${2:-}" ]]; then
          echo "ERROR - --dir requires a directory argument" >&2
          exit 1
        fi
        root_dir="${2%/}"
        shift 2
        ;;
      -e|--exclude)
        if [[ -z "${2:-}" ]]; then
          echo "ERROR - --exclude requires a directory argument" >&2
          exit 1
        fi
        # Reduce to a basename glob so -e matches the same way as discover.sh's
        # 'flux schema discover --skip-file' (which only matches basenames).
        exclude_dirs+=("$(basename "${2%/}")")
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "ERROR - Unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
}

check_prerequisites() {
  local missing=0
  # Resolve kustomize: prefer the standalone binary (independently updatable),
  # otherwise fall back to kubectl's embedded kustomize.
  if command -v kustomize &> /dev/null; then
    kustomize_cmd=(kustomize build)
  elif command -v kubectl &> /dev/null; then
    kustomize_cmd=(kubectl kustomize)
  else
    echo "ERROR - neither kustomize nor kubectl is installed" >&2
    missing=1
  fi
  # Resolve how to invoke flux-schema: prefer the 'flux schema' plugin dispatch,
  # otherwise fall back to a standalone flux-schema binary on PATH.
  if command -v flux &> /dev/null && flux schema version &> /dev/null; then
    flux_schema=(flux schema)
  elif command -v flux-schema &> /dev/null; then
    flux_schema=(flux-schema)
  else
    echo "ERROR - flux-schema is not installed" >&2
    echo "ERROR - Install it with: flux plugin install schema" >&2
    missing=1
  fi
  if [[ $missing -ne 0 ]]; then
    exit 1
  fi
}

# List files matching glob patterns under root_dir, skipping dot-directories.
# Outputs null-terminated paths. Mirrors flux-schema's on-disk walk so that
# discovery and validation see the same set of files.
# Usage: find_files '*.yaml' or find_files '*.tf' 'Chart.yaml'
find_files() {
  local name_args=()
  local first=true
  for pattern in "$@"; do
    if $first; then
      name_args+=(-name "$pattern")
      first=false
    else
      name_args+=(-o -name "$pattern")
    fi
  done
  find "$root_dir" -path '*/.*' -prune -o -type f \( "${name_args[@]}" \) -print0
}

# Normalize a path by stripping leading "./" for consistent comparisons
normalize_path() {
  local p="${1#./}"
  echo "${p%/}"
}

# Check if any component of a path matches a user -e basename glob
matches_user_exclude() {
  local path comp pat
  path="$(normalize_path "$1")"
  local -a comps
  IFS='/' read -ra comps <<< "$path"
  for comp in "${comps[@]}"; do
    for pat in "${exclude_dirs[@]}"; do
      # shellcheck disable=SC2053  # intentional glob match, not literal
      if [[ "$comp" == $pat ]]; then
        return 0
      fi
    done
  done
  return 1
}

# Check if a path is under a user-excluded, auto-skipped, or kustomize directory
is_excluded_dir() {
  local path
  path="$(normalize_path "$1")"
  if matches_user_exclude "$path"; then
    return 0
  fi
  for dir in "${!auto_skip_dirs[@]}"; do
    local d
    d="$(normalize_path "$dir")"
    if [[ "$path" == "$d"/* || "$path" == "$d" ]]; then
      return 0
    fi
  done
  for dir in "${!kustomize_dirs[@]}"; do
    local d
    d="$(normalize_path "$dir")"
    if [[ "$path" == "$d"/* || "$path" == "$d" ]]; then
      return 0
    fi
  done
  return 1
}

# Check if a path is under a user-excluded or auto-skipped directory (but not kustomize dirs)
is_non_kustomize_excluded_dir() {
  local path
  path="$(normalize_path "$1")"
  if matches_user_exclude "$path"; then
    return 0
  fi
  for dir in "${!auto_skip_dirs[@]}"; do
    local d
    d="$(normalize_path "$dir")"
    if [[ "$path" == "$d"/* || "$path" == "$d" ]]; then
      return 0
    fi
  done
  return 1
}

# Detect directories containing Terraform files, Helm charts, or kustomize overlays
detect_excluded_dirs() {
  while IFS= read -r -d $'\0' file; do
    auto_skip_dirs["$(dirname "$file")"]=1
  done < <(find_files '*.tf' 'Chart.yaml')

  while IFS= read -r -d $'\0' file; do
    kustomize_dirs["$(dirname "$file")"]=1
  done < <(find_files "$kustomize_config")
}

# Parse a captured flux-schema run: echo its output so the agent still sees
# every per-resource line, then add the Valid/Invalid/Skipped counts from its
# Summary line into the running totals.
accumulate() {
  local output="$1"
  last_run_had_summary=0
  printf '%s\n' "$output"
  while IFS= read -r line; do
    if [[ "$line" =~ Valid:\ ([0-9]+),\ Invalid:\ ([0-9]+),\ Skipped:\ ([0-9]+) ]]; then
      total_valid=$((total_valid + BASH_REMATCH[1]))
      total_invalid=$((total_invalid + BASH_REMATCH[2]))
      total_skipped=$((total_skipped + BASH_REMATCH[3]))
      last_run_had_summary=1
    fi
  done <<< "$output"
}

# Guard against silent tool failures: flux-schema exits nonzero either because
# resources were invalid (already counted via the Summary) or because it could
# not run at all (no Summary). The latter must not be mistaken for success.
check_tool_status() {
  local status="$1"
  if [[ $status -ne 0 && $last_run_had_summary -eq 0 ]]; then
    echo "ERROR - flux-schema exited with status ${status} without a result summary" >&2
    tool_errors=$((tool_errors + 1))
  fi
}

validate_kubernetes_manifests() {
  echo "INFO - Validating Kubernetes manifests"
  # Collect plain manifests, skipping overlay/terraform/helm directories.
  # Overlays are validated separately from their built output.
  local files=()
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_excluded_dir "$dir"; then
      continue
    fi
    files+=("$file")
  done < <(find_files '*.yaml' '*.yml')

  if [[ ${#files[@]} -eq 0 ]]; then
    return
  fi

  # --skip-file kustomization.yaml so kustomize build configs are not
  # validated against the catalog as Kubernetes API resources.
  local output status
  output="$("${flux_schema[@]}" validate "${files[@]}" "${flux_schema_flags[@]}" \
    --skip-file "$kustomize_config" --verbose 2>&1)"
  status=$?
  accumulate "$output"
  check_tool_status "$status"
}

validate_kustomize_overlays() {
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_non_kustomize_excluded_dir "$dir"; then
      continue
    fi
    local overlay="${file/%$kustomize_config}"
    echo "INFO - Validating kustomize overlay ${overlay}"
    # Build first so a kustomize failure is reported against this overlay path
    # instead of surfacing as an unattributed broken pipe. Capture stdout only —
    # kustomize warnings on stderr flow to the terminal and must not enter the
    # rendered stream, or flux-schema would validate them as manifests.
    local built output status
    if ! built="$("${kustomize_cmd[@]}" "$overlay" "${kustomize_flags[@]}")"; then
      echo "ERROR - kustomize build failed for overlay ${overlay}" >&2
      build_errors=$((build_errors + 1))
      continue
    fi
    output="$(printf '%s\n' "$built" | "${flux_schema[@]}" validate "${flux_schema_flags[@]}" --verbose 2>&1)"
    status=$?
    accumulate "$output"
    check_tool_status "$status"
  done < <(find_files "$kustomize_config")
}

# Main
parse_args "$@"
check_prerequisites
if [[ ! -d "$root_dir" ]]; then
  echo "ERROR - directory not found: $root_dir" >&2
  exit 1
fi
detect_excluded_dirs
validate_kubernetes_manifests
validate_kustomize_overlays

if [[ $total_invalid -gt 0 || $build_errors -gt 0 || $tool_errors -gt 0 ]]; then
  parts=()
  [[ $total_invalid -gt 0 ]] && parts+=("${total_invalid} invalid resource(s)")
  [[ $build_errors -gt 0 ]] && parts+=("${build_errors} kustomize overlay(s) failed to build")
  [[ $tool_errors -gt 0 ]] && parts+=("${tool_errors} flux-schema run(s) failed to execute")
  echo "ERROR - Validation failed: $(IFS="; "; echo "${parts[*]}") (${total_valid} valid, ${total_skipped} skipped)" >&2
  exit 1
fi
echo "INFO - All validations passed (${total_valid} valid, ${total_skipped} skipped)"
