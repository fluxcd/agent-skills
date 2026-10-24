#!/usr/bin/env bash
# Copyright 2026 The Flux authors. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script="$here/check-deprecated.sh"
test_tmp=$(mktemp -d)
trap 'rm -rf -- "$test_tmp"; test ! -e "$test_tmp"' EXIT
mkdir -p "$test_tmp/bin" "$test_tmp/repository with spaces"
printf 'apiVersion: source.toolkit.fluxcd.io/v1\nkind: GitRepository\n' >"$test_tmp/repository with spaces/source.yaml"
cp "$test_tmp/repository with spaces/source.yaml" "$test_tmp/original.yaml"
cat >"$test_tmp/bin/flux" <<'FLUX'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'version --client') printf '%s\n' "${FLUX_TEST_VERSION:-flux: v2.9.0}" ;;
  'migrate -f . --dry-run')
    [ "$PWD" = "$FLUX_TEST_DIRECTORY" ] || {
      printf 'Unexpected scan directory: %s\n' "$PWD" >&2
      exit 97
    }
    case "$FLUX_TEST_MODE" in
      clean) ;;
      deprecated) printf 'source.yaml:1: GitRepository v1beta2 -> v1\n' ;;
      deprecated-large)
        for ((i=0; i<5000; i++)); do
          printf 'directory/with/a/long/resource/path/source.yaml:1: GitRepository v1beta2 -> v1\n'
        done ;;
      unrelated-arrow) printf 'INFO - cache -> cache\n' ;;
      error-empty) exit 81 ;;
      error-text) printf 'ERROR - synthetic scan failure\n' >&2; exit 81 ;;
      error-one) printf 'ERROR - synthetic scan failure\n' >&2; exit 1 ;;
      error-partial-clean) printf 'INFO - scanned first file successfully\n'; exit 81 ;;
      error-partial-arrow) printf 'source.yaml:1: GitRepository v1beta2 -> v1\n'; exit 81 ;;
      *) exit 98 ;;
    esac ;;
  *) printf 'Unexpected Flux invocation: %s\n' "$*" >&2; exit 97 ;;
esac
FLUX
chmod +x "$test_tmp/bin/flux"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run_case() {
  local mode=$1 want=$2 version=${3:-flux: v2.9.0} directory=${4:-$test_tmp/repository with spaces} status=0
  PATH="$test_tmp/bin:$PATH" FLUX_TEST_MODE="$mode" FLUX_TEST_VERSION="$version" \
    FLUX_TEST_DIRECTORY="$directory" \
    bash "$script" --dir "$directory" >"$test_tmp/output" 2>&1 || status=$?
  [ "$status" -eq "$want" ] || fail "$mode returned $status; expected $want"
  if [ "$want" -eq 0 ]; then
    grep -Fq 'No deprecated Flux API versions found' "$test_tmp/output" ||
      fail "$mode did not report a completed clean scan"
  elif grep -Fq 'No deprecated Flux API versions found' "$test_tmp/output"; then
    fail "$mode made a clean-audit claim after failure"
  fi
  cmp "$test_tmp/original.yaml" "$test_tmp/repository with spaces/source.yaml" ||
    fail "$mode changed the scanned file"
}

run_case clean 0
run_case deprecated 1
grep -Fq 'deprecated Flux API versions found' "$test_tmp/output" || fail 'deprecated result lost its classification'
run_case deprecated-large 1
grep -Fq 'deprecated Flux API versions found' "$test_tmp/output" || fail 'large deprecated result lost its classification'
run_case unrelated-arrow 0
for mode in error-empty error-text error-partial-clean error-partial-arrow; do
  run_case "$mode" 81
  grep -Fq 'Flux API scan failed' "$test_tmp/output" || fail "$mode lost the failure diagnostic"
  if grep -Fq 'ERROR - deprecated Flux API versions found' "$test_tmp/output"; then
    fail "$mode classified an incomplete scan as deprecated APIs"
  fi
  case "$mode" in
    error-text) grep -Fq 'synthetic scan failure' "$test_tmp/output" || fail 'scan diagnostic was lost' ;;
    error-partial-clean) grep -Fq 'scanned first file successfully' "$test_tmp/output" || fail 'partial scan output was lost' ;;
    error-partial-arrow) grep -Fq 'GitRepository v1beta2 -> v1' "$test_tmp/output" || fail 'partial migration finding was lost' ;;
  esac
done
run_case error-one 1
grep -Fq 'Flux API scan failed' "$test_tmp/output" || fail 'exit 1 lost its failure diagnostic'
grep -Fq 'synthetic scan failure' "$test_tmp/output" || fail 'exit 1 lost the Flux diagnostic'
if grep -Fq 'ERROR - deprecated Flux API versions found' "$test_tmp/output"; then
  fail 'exit 1 was incorrectly classified as deprecated APIs'
fi
run_case clean 1 'flux: v2.8.9'
grep -Fq 'too old' "$test_tmp/output" || fail 'old Flux version was not rejected by its version check'
run_case clean 1 'unparseable version'
grep -Fq 'unable to determine' "$test_tmp/output" || fail 'unparseable version was not rejected'
run_case clean 1 'flux: v2.9.0' "$test_tmp/missing-directory"
grep -Fq 'directory not found' "$test_tmp/output" || fail 'missing directory was not rejected'
mkdir "$test_tmp/no-flux"
status=0
PATH="$test_tmp/no-flux" "$BASH" "$script" --dir "$test_tmp/repository with spaces" \
  >"$test_tmp/output" 2>&1 || status=$?
[ "$status" -ne 0 ] || fail 'missing Flux CLI was accepted'
grep -Fq 'flux is not installed' "$test_tmp/output" || fail 'missing Flux CLI failed for an unrelated reason'
printf 'check-deprecated: clean, deprecated, partial-failure and prerequisite controls passed\n'
