#!/usr/bin/env bash

# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Tests for skills/gitops-repo-audit/scripts/check-deprecated.sh using a fake
# flux binary. Expected exit codes: 0 clean, 1 deprecated, 2 scan not completed.

set -o errexit
set -o nounset
set -o pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/skills/gitops-repo-audit/scripts/check-deprecated.sh"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

scan_dir="$tmp/repository with spaces"
mkdir -p "$tmp/bin" "$scan_dir"
printf 'apiVersion: source.toolkit.fluxcd.io/v1\nkind: GitRepository\n' >"$scan_dir/source.yaml"
cp "$scan_dir/source.yaml" "$tmp/original.yaml"

cat >"$tmp/bin/flux" <<'FLUX'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'version --client') printf '%s\n' "${FLUX_TEST_VERSION:-flux: v2.9.0}" ;;
  'migrate -f . --dry-run')
    [[ "$PWD" == "$FLUX_TEST_DIRECTORY" ]] || {
      printf 'Unexpected scan directory: %s\n' "$PWD" >&2
      exit 97
    }
    case "$FLUX_TEST_MODE" in
      clean) ;;
      deprecated) printf '✚ source.yaml:1: GitRepository v1beta2 -> v1\n' ;;
      deprecated-large)
        for ((i=0; i<5000; i++)); do
          printf '✚ directory/with/a/long/resource/path/source.yaml:1: GitRepository v1beta2 -> v1\n'
        done ;;
      unrelated-arrow) printf 'INFO - cache -> cache\n' ;;
      error-empty) exit 81 ;;
      error-text) printf '✗ synthetic scan failure\n' >&2; exit 1 ;;
      error-partial-clean) printf 'INFO - scanned first file successfully\n'; exit 1 ;;
      error-partial-arrow) printf '✚ source.yaml:1: GitRepository v1beta2 -> v1\n'; exit 1 ;;
      *) exit 98 ;;
    esac ;;
  *) printf 'Unexpected Flux invocation: %s\n' "$*" >&2; exit 97 ;;
esac
FLUX
chmod +x "$tmp/bin/flux"

out="$tmp/output"
passed=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  sed 's/^/  | /' "$out" >&2
  exit 1
}

# run_case <name> <want-exit> [flux-version] [dir]
run_case() {
  local name=$1 want=$2 version=${3:-flux: v2.9.0} dir=${4:-$scan_dir} status=0
  PATH="$tmp/bin:$PATH" FLUX_TEST_MODE="$name" FLUX_TEST_VERSION="$version" \
    FLUX_TEST_DIRECTORY="$dir" \
    bash "$script" --dir "$dir" >"$out" 2>&1 || status=$?
  [[ "$status" -eq "$want" ]] || fail "$name: exit $status, want $want"
  if [[ "$want" -eq 0 ]]; then
    grep -Fq 'No deprecated Flux API versions found' "$out" || fail "$name: missing clean result"
  elif grep -Fq 'No deprecated Flux API versions found' "$out"; then
    fail "$name: reported a clean result"
  fi
  cmp -s "$tmp/original.yaml" "$scan_dir/source.yaml" || fail "$name: scanned file was modified"
  passed=$((passed + 1))
}

expect() { grep -Fq -- "$1" "$out" || fail "$2"; }
reject() { ! grep -Fq -- "$1" "$out" || fail "$2"; }

# Completed scans
run_case clean 0
run_case unrelated-arrow 0
run_case deprecated 1
expect 'deprecated Flux API versions found' 'deprecated: missing finding'
run_case deprecated-large 1
expect 'deprecated Flux API versions found' 'deprecated-large: finding lost on large output'

# Failed scans are reported as failures, never as clean or deprecated
for mode in error-empty error-text error-partial-clean error-partial-arrow; do
  run_case "$mode" 2
  expect 'Flux API scan failed' "$mode: missing failure diagnostic"
  reject 'ERROR - deprecated Flux API versions found' "$mode: incomplete scan classified as deprecated"
done
run_case error-text 2
expect 'synthetic scan failure' 'error-text: flux diagnostic lost'
run_case error-partial-arrow 2
expect 'GitRepository v1beta2 -> v1' 'error-partial-arrow: partial output lost'

# Prerequisite failures
run_case clean 2 'flux: v2.8.9'
expect 'too old' 'old flux version not rejected'
run_case clean 2 'unparseable version'
expect 'unable to determine' 'unparseable flux version not rejected'
run_case clean 2 'flux: v2.9.0' "$tmp/missing-directory"
expect 'directory not found' 'missing directory not rejected'

status=0
PATH="$tmp/empty-path" "$BASH" "$script" --dir "$scan_dir" >"$out" 2>&1 || status=$?
[[ "$status" -eq 2 ]] || fail "missing flux: exit $status, want 2"
expect 'flux is not installed' 'missing flux: wrong diagnostic'
passed=$((passed + 1))

printf 'PASS: check-deprecated (%d cases)\n' "$passed"
