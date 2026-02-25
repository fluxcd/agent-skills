#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script scans a directory for Kubernetes and Flux resources
# and outputs an inventory report with counts by kind and directory.

# Prerequisites
# - awk

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
  if ! command -v awk &> /dev/null; then
    echo "ERROR - awk is not installed" >&2
    exit 1
  fi
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
      while IFS= read -r -d '' f; do
        [[ "$f" == .* || "$f" == */.* ]] && continue
        printf '%s\0' "$root_dir/$f"
      done
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

declare -A auto_skip_dirs=()

detect_excluded_dirs() {
  while IFS= read -r -d $'\0' file; do
    auto_skip_dirs["$(dirname "$file")"]=1
  done < <(find_files '*.tf' 'Chart.yaml')
}

is_excluded() {
  local path="$1"
  for dir in "${exclude_dirs[@]}" "${!auto_skip_dirs[@]}"; do
    if [[ "$path" == "$dir"/* || "$path" == "$dir" ]]; then
      return 0
    fi
  done
  return 1
}

discover() {
  # Collect non-excluded YAML files
  local files=()
  while IFS= read -r -d $'\0' file; do
    dir="$(dirname "$file")"
    if is_excluded "$dir"; then
      continue
    fi
    files+=("$file")
  done < <(find_files '*.yaml')

  if [[ ${#files[@]} -eq 0 ]]; then
    echo '{}'
    return
  fi

  # Single-pass extraction using awk: reads top-level kind/apiVersion from
  # each YAML document across all files, categorizes, counts, and outputs JSON.
  awk -v root_dir="$root_dir" '
    FNR == 1 || /^---[[:space:]]*$/ { kind = ""; api = "" }
    /^kind:[[:space:]]/ {
      val = $0; sub(/^kind:[[:space:]]+/, "", val); gsub(/["\047\r]/, "", val); kind = val
    }
    /^apiVersion:[[:space:]]/ {
      val = $0; sub(/^apiVersion:[[:space:]]+/, "", val); gsub(/["\047\r]/, "", val); api = val
    }
    kind != "" && api != "" {
      dir = FILENAME
      if (index(dir, "/") > 0) sub(/\/[^\/]*$/, "", dir); else dir = "."
      rd_len = length(root_dir)
      if (rd_len > 0 && substr(dir, 1, rd_len) == root_dir) {
        dir = substr(dir, rd_len + 1)
        sub(/^\//, "", dir)
      }
      if (dir == "") dir = "."

      if (api ~ /kustomize\.config\.k8s\.io/) {
        kust_dirs[dir]++
      } else if (api ~ /fluxcd/) {
        flux_kinds[kind]++
        flux_dirs[dir]++
      } else {
        k8s_kinds[kind]++
        k8s_dirs[dir]++
      }
      kind = ""; api = ""
    }
    function print_obj(arr,    s, k) {
      printf "{"
      s = ""
      for (k in arr) { printf "%s\n      \"%s\": %d", s, k, arr[k]; s = "," }
      if (s != "") printf "\n    "
      printf "}"
    }
    END {
      printf "{\n"
      printf "  \"fluxResources\": {\n"
      printf "    \"byKind\": "; print_obj(flux_kinds)
      printf ",\n    \"byDirectory\": "; print_obj(flux_dirs)
      printf "\n  },\n"
      printf "  \"kubernetesResources\": {\n"
      printf "    \"byKind\": "; print_obj(k8s_kinds)
      printf ",\n    \"byDirectory\": "; print_obj(k8s_dirs)
      printf "\n  },\n"
      printf "  \"kustomizeOverlays\": {\n"
      printf "    \"byDirectory\": "; print_obj(kust_dirs)
      printf "\n  }\n"
      printf "}\n"
    }
  ' "${files[@]}"
}

# Main
parse_args "$@"
check_prerequisites
detect_excluded_dirs
discover
