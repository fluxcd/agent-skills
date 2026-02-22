#!/usr/bin/env bash

# Copyright 2023-2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script validates the Flux custom resources and the kustomize
# overlays using kubeconform against the Flux OpenAPI schemas bundled
# in the assets directory.

# Prerequisites
# - yq >= 4.50
# - kustomize >= 5.8
# - kubeconform >= 0.7

set -o errexit
set -o pipefail

# resolve the skill root directory (parent of scripts/)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "$script_dir/.." && pwd)"
assets_schemas_dir="$skill_dir/assets/schemas"

# mirror kustomize-controller build options
kustomize_flags=("--load-restrictor=LoadRestrictionsNone")
kustomize_config="kustomization.yaml"

# skip Kubernetes Secrets due to SOPS fields failing validation
kubeconform_flags=("-skip=Secret")
kubeconform_config=("-strict" "-ignore-missing-schemas" "-schema-location" "default" "-verbose")

# root directory to validate
root_dir="."

# directories to exclude from validation
exclude_dirs=()

# directories auto-detected as non-Kubernetes (terraform, helm charts)
declare -A auto_skip_dirs=()

# directories that are kustomize overlays
declare -A kustomize_dirs=()

usage() {
  echo "Usage: $0 [-d <dir>] [-e <dir>]... [-h]"
  echo ""
  echo "Validate Flux custom resources and kustomize overlays using kubeconform."
  echo ""
  echo "Options:"
  echo "  -d, --dir <dir>      Root directory to validate (default: current directory)"
  echo "  -e, --exclude <dir>  Directory to exclude from validation (can be repeated)"
  echo "  -h, --help           Show this help message"
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
        exclude_dirs+=("./${2#./}")
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
  for cmd in yq kustomize kubeconform; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "ERROR - $cmd is not installed" >&2
      missing=1
    fi
  done
  if [[ ! -d "$assets_schemas_dir/master-standalone-strict" ]]; then
    echo "ERROR - Flux OpenAPI schemas not found in $assets_schemas_dir" >&2
    echo "ERROR - Run 'make download-schemas' to fetch them" >&2
    missing=1
  fi
  if [[ $missing -ne 0 ]]; then
    exit 1
  fi
}

setup_schemas() {
  kubeconform_config+=("-schema-location" "$assets_schemas_dir")
}

# List files matching glob patterns under root_dir, respecting .gitignore.
# Outputs null-terminated paths. Falls back to find for non-git directories.
# Usage: find_files '*.yaml' or find_files '*.tf' 'Chart.yaml'
find_files() {
  if git -C "$root_dir" rev-parse --is-inside-work-tree &>/dev/null; then
    # Literal filenames need **/ prefix for recursive matching in git pathspec;
    # glob patterns (containing * ? [) already match recursively.
    local git_patterns=()
    for pattern in "$@"; do
      if [[ "$pattern" == *'*'* || "$pattern" == *'?'* || "$pattern" == *'['* ]]; then
        git_patterns+=("$pattern")
      else
        git_patterns+=("**/$pattern")
      fi
    done
    git -C "$root_dir" ls-files -z --cached --others --exclude-standard -- "${git_patterns[@]}" | \
      while IFS= read -r -d '' f; do printf '%s\0' "$root_dir/$f"; done
  else
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
  fi
}

# Normalize a path by stripping leading "./" for consistent comparisons
normalize_path() {
  local p="${1#./}"
  echo "${p%/}"
}

# Check if a path is under a user-excluded, auto-skipped, or kustomize directory
is_excluded_dir() {
  local path
  path="$(normalize_path "$1")"
  for dir in "${exclude_dirs[@]}"; do
    local d
    d="$(normalize_path "$dir")"
    if [[ "$path" == "$d"/* || "$path" == "$d" ]]; then
      return 0
    fi
  done
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
  for dir in "${exclude_dirs[@]}" "${!auto_skip_dirs[@]}"; do
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

validate_yaml_syntax() {
  echo "INFO - Validating YAML syntax"
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_excluded_dir "$dir"; then
      continue
    fi
    yq e 'true' "$file" > /dev/null
  done < <(find_files '*.yaml')
}

validate_kubernetes_manifests() {
  echo "INFO - Validating Kubernetes manifests"
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_excluded_dir "$dir"; then
      continue
    fi
    kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}" "${file}"
  done < <(find_files '*.yaml')
}

validate_kustomize_overlays() {
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_non_kustomize_excluded_dir "$dir"; then
      continue
    fi
    echo "INFO - Validating kustomize overlay ${file/%$kustomize_config}"
    kustomize build "${file/%$kustomize_config}" "${kustomize_flags[@]}" | \
      kubeconform "${kubeconform_flags[@]}" "${kubeconform_config[@]}"
    if [[ ${PIPESTATUS[0]} != 0 || ${PIPESTATUS[1]} != 0 ]]; then
      exit 1
    fi
  done < <(find_files "$kustomize_config")
}

# Main
parse_args "$@"
check_prerequisites
setup_schemas
detect_excluded_dirs
validate_yaml_syntax
validate_kubernetes_manifests
validate_kustomize_overlays
echo "INFO - All validations passed"
