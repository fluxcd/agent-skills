#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# This script checks for deprecated Flux API versions in a directory.
# If the flux CLI is available, it uses `flux migrate --dry-run` for detection.
# Otherwise, it falls back to grep-based scanning against known deprecated versions.

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

echo "Checking for deprecated Flux API versions in $dir"
echo ""

found=0

if command -v flux &> /dev/null; then
  echo "Using flux CLI $(flux version --client | head -1)"
  echo ""
  output=$(cd "$dir" && flux migrate -f . --dry-run 2>&1) || true
  echo "$output"
  if echo "$output" | grep -qE "✚|->"; then
    found=1
  fi
else
  echo "flux CLI not found, falling back to grep-based scanning"
  echo ""

  deprecated_versions=(
    "source.toolkit.fluxcd.io/v1beta1"
    "source.toolkit.fluxcd.io/v1beta2"
    "kustomize.toolkit.fluxcd.io/v1beta1"
    "kustomize.toolkit.fluxcd.io/v1beta2"
    "helm.toolkit.fluxcd.io/v2beta1"
    "helm.toolkit.fluxcd.io/v2beta2"
    "notification.toolkit.fluxcd.io/v1beta1"
    "notification.toolkit.fluxcd.io/v1beta2"
    "image.toolkit.fluxcd.io/v1beta1"
    "image.toolkit.fluxcd.io/v1beta2"
  )

  for version in "${deprecated_versions[@]}"; do
    matches=$(grep -rl "apiVersion: $version" "$dir" --include='*.yaml' --include='*.yml' 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      found=1
      echo "DEPRECATED: $version"
      echo "$matches" | while read -r file; do
        echo "  - $file"
      done
      echo ""
    fi
  done
fi

if [[ "$found" -eq 0 ]]; then
  echo "No deprecated Flux API versions found."
fi

exit $found
