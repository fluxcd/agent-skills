#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script checks for deprecated Flux API versions in a directory using the
# flux CLI's migrate command in dry-run mode. It reports the exact resources and
# the versions they should migrate to; exit code 1 means deprecated APIs found.

# Prerequisites
# - flux (https://fluxcd.io/flux/installation/)

set -o errexit
set -o pipefail

root_dir="."

usage() {
  echo "Usage: $0 [-d <dir>] [-h]"
  echo ""
  echo "Check a directory for deprecated Flux API versions."
  echo ""
  echo "Options:"
  echo "  -d, --dir <dir>  Root directory to scan (default: current directory)"
  echo "  -h, --help       Show this help message"
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
  if ! command -v flux &> /dev/null; then
    echo "ERROR - flux is not installed" >&2
    echo "ERROR - Install it from https://fluxcd.io/flux/installation/" >&2
    exit 1
  fi
}

check_deprecated() {
  echo "INFO - Checking for deprecated Flux API versions in ${root_dir}"
  echo "INFO - Using $(flux version --client 2>&1 | head -1)"

  # flux migrate dry-run prints one line per resource that references a
  # deprecated API version, e.g.:
  #   ✚ infrastructure/nginx.yaml:11: HelmRelease v2beta2 -> v2
  # Match the versioned-arrow shape ('vX... -> vY...') rather than any bare
  # '✚' or '->' so unrelated arrows in flux output can't cause a false positive.
  local output
  output="$(cd "$root_dir" && flux migrate -f . --dry-run 2>&1)" || true
  echo "$output"

  if echo "$output" | grep -qE " v[0-9][a-zA-Z0-9]* -> v[0-9]"; then
    echo "ERROR - deprecated Flux API versions found" >&2
    return 1
  fi
  echo "INFO - No deprecated Flux API versions found"
}

# Main
parse_args "$@"
check_prerequisites
if [[ ! -d "$root_dir" ]]; then
  echo "ERROR - directory not found: $root_dir" >&2
  exit 1
fi
check_deprecated
