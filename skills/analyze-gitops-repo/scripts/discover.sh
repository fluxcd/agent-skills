#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script scans a directory for Kubernetes and Flux resources
# and outputs an inventory report with counts by kind and directory.

# Prerequisites
# - yq >= 4.50

set -o errexit
set -o pipefail

root_dir="."
exclude_dirs=()

usage() {
  echo "Usage: $0 [-d <dir>] [-e <dir>]... [-h]"
  echo ""
  echo "Discover Kubernetes resources and output an inventory report."
  echo ""
  echo "Options:"
  echo "  -d, --dir <dir>      Root directory to scan (default: current directory)"
  echo "  -e, --exclude <dir>  Directory to exclude from scanning (can be repeated)"
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
        exclude_dirs+=("${2%/}")
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
  if ! command -v yq &> /dev/null; then
    echo "ERROR - yq is not installed" >&2
    exit 1
  fi
}

declare -a auto_skip_dirs=()

detect_excluded_dirs() {
  while IFS= read -r -d $'\0' file; do
    auto_skip_dirs+=("$(dirname "$file")")
  done < <(find "$root_dir" -path '*/.*' -prune -o -type f \( -name '*.tf' -o -name 'Chart.yaml' \) -print0)
}

is_excluded() {
  local path="$1"
  for dir in "${exclude_dirs[@]}" "${auto_skip_dirs[@]}"; do
    if [[ "$path" == "$dir"/* || "$path" == "$dir" ]]; then
      return 0
    fi
  done
  return 1
}

discover() {
  declare -A flux_kind_counts
  declare -A flux_dir_counts
  declare -A k8s_kind_counts
  declare -A k8s_dir_counts
  declare -A kustomize_dir_counts

  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_excluded "$dir"; then
      continue
    fi

    local rel_dir="${dir#"$root_dir"}"
    rel_dir="${rel_dir#/}"
    [[ -z "$rel_dir" ]] && rel_dir="."

    # extract kind and apiVersion from each document in the file
    while IFS=$'\t' read -r kind api_version; do
      [[ -z "$kind" || "$kind" == "null" ]] && continue
      [[ -z "$api_version" || "$api_version" == "null" ]] && continue

      case "$api_version" in
        *kustomize.config.k8s.io*)
          kustomize_dir_counts["$rel_dir"]=$(( ${kustomize_dir_counts["$rel_dir"]:-0} + 1 ))
          continue
          ;;
        *fluxcd*)
          flux_kind_counts["$kind"]=$(( ${flux_kind_counts["$kind"]:-0} + 1 ))
          flux_dir_counts["$rel_dir"]=$(( ${flux_dir_counts["$rel_dir"]:-0} + 1 ))
          ;;
        *)
          k8s_kind_counts["$kind"]=$(( ${k8s_kind_counts["$kind"]:-0} + 1 ))
          k8s_dir_counts["$rel_dir"]=$(( ${k8s_dir_counts["$rel_dir"]:-0} + 1 ))
          ;;
      esac
    done < <(yq eval -N '.kind + "\t" + .apiVersion' "$file" 2>/dev/null)
  done < <(find "$root_dir" -path '*/.*' -prune -o -type f -name '*.yaml' -print0)

  # build JSON output
  local json="{"

  # flux resources
  json+="\"fluxResources\":{\"byKind\":{"
  local first=true
  for kind in $(echo "${!flux_kind_counts[@]}" | tr ' ' '\n' | sort); do
    $first || json+=","
    json+="\"$kind\":${flux_kind_counts[$kind]}"
    first=false
  done
  json+="},\"byDirectory\":{"
  first=true
  for dir in $(echo "${!flux_dir_counts[@]}" | tr ' ' '\n' | sort); do
    $first || json+=","
    json+="\"$dir\":${flux_dir_counts[$dir]}"
    first=false
  done
  json+="}}"

  # kubernetes resources
  json+=",\"kubernetesResources\":{\"byKind\":{"
  first=true
  for kind in $(echo "${!k8s_kind_counts[@]}" | tr ' ' '\n' | sort); do
    $first || json+=","
    json+="\"$kind\":${k8s_kind_counts[$kind]}"
    first=false
  done
  json+="},\"byDirectory\":{"
  first=true
  for dir in $(echo "${!k8s_dir_counts[@]}" | tr ' ' '\n' | sort); do
    $first || json+=","
    json+="\"$dir\":${k8s_dir_counts[$dir]}"
    first=false
  done
  json+="}}"

  # kustomize overlays
  json+=",\"kustomizeOverlays\":{\"byDirectory\":{"
  first=true
  for dir in $(echo "${!kustomize_dir_counts[@]}" | tr ' ' '\n' | sort); do
    $first || json+=","
    json+="\"$dir\":${kustomize_dir_counts[$dir]}"
    first=false
  done
  json+="}}}"

  echo "$json" | yq -P -o json
}

# Main
parse_args "$@"
check_prerequisites
detect_excluded_dirs
discover
