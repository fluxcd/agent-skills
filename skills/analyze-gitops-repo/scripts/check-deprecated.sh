#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script checks for deprecated Flux API versions in a directory
# using the flux CLI's migrate command in dry-run mode.
# Requires: flux CLI (https://fluxcd.io/flux/installation/)

set -o errexit
set -o pipefail

usage() {
  echo "Usage: $(basename "$0") -d <directory>"
  echo ""
  echo "Options:"
  echo "  -d  Directory to scan for deprecated Flux APIs"
  echo "  -h  Show this help message"
  exit 1
}

dir=""

while getopts "d:h" opt; do
  case $opt in
    d) dir="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$dir" ]]; then
  echo "Error: directory is required"
  usage
fi

if [[ ! -d "$dir" ]]; then
  echo "Error: $dir is not a directory"
  exit 1
fi

if ! command -v flux &> /dev/null; then
  echo "Error: flux CLI is required but not found"
  echo "Install it from https://fluxcd.io/flux/installation/"
  exit 1
fi

echo "Checking for deprecated Flux API versions in $dir"
echo "Using $(flux version --client 2>&1 | head -1)"
echo ""

output=$(cd "$dir" && flux migrate -f . --dry-run 2>&1) || true
echo "$output"

if echo "$output" | grep -qE "✚|->"; then
  exit 1
fi
