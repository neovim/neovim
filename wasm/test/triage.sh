#!/usr/bin/env bash
# wasm/test/triage.sh - sweep functional spec files against the wasm build,
# one runner invocation per file with a hard timeout, and bucket the results.
#
# The upstream harness has no per-test timeout, and a wasm-side hang (a request
# that never answers) would otherwise stall a whole-suite run. Running
# file-by-file bounds the damage to one file and isolates harness state.
#
# Usage:
#   wasm/test/triage.sh [spec dir or file...]     (default: test/functional)
# Env:
#   JOBS          parallel workers (default: 8)
#   FILE_TIMEOUT  seconds per spec file (default: 180)
#   OUT_DIR       results dir (default: build/wasm-triage)
#
# Output: $OUT_DIR/results.tsv (file, status, counts, last test on timeout)
# and per-file logs in $OUT_DIR/logs/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JOBS="${JOBS:-8}"
FILE_TIMEOUT="${FILE_TIMEOUT:-180}"
OUT_DIR="${OUT_DIR:-$ROOT/build/wasm-triage}"

targets=("${@:-test/functional}")
mapfile -t files < <(cd "$ROOT" && find "${targets[@]}" -name '*_spec.lua' | sort)
echo "triage: ${#files[@]} spec files, $JOBS workers, ${FILE_TIMEOUT}s/file"

mkdir -p "$OUT_DIR/logs"
: > "$OUT_DIR/results.tsv"

run_one() {
  local spec="$1"
  local slug log status passed failed errors last
  slug="$(basename "$OUT_DIR")_$(echo "$spec" | sed 's|^test/functional/||; s|_spec\.lua$||; s|/|__|g')"
  log="$OUT_DIR/logs/$slug.log"
  set +e
  TEST_SUFFIX="_$slug" TEST_TIMEOUT="$FILE_TIMEOUT" \
    "$ROOT/wasm/test/run-functional.sh" "$spec" > "$log" 2>&1
  local rc=$?
  set -e
  # Strip ANSI colors for parsing.
  local clean
  clean="$(sed 's/\x1b\[[0-9;]*m//g' "$log")"
  passed="$(echo "$clean" | grep -oE 'PASSED +[0-9]+ tests' | grep -oE '[0-9]+' | tail -1)"
  failed="$(echo "$clean" | grep -cE '^RUN .* FAIL$' || true)"
  errors="$(echo "$clean" | grep -cE '^RUN .* ERR$' || true)"
  if [ "$rc" -eq 124 ]; then
    status=TIMEOUT
    last="$(echo "$clean" | grep -E '^RUN' | tail -1 | sed 's/^RUN *//; s/:.*$//')"
  elif [ "$rc" -eq 0 ]; then
    status=PASS
    last=""
  else
    status=FAIL
    last=""
  fi
  printf '%s\t%s\trc=%s\tpass=%s\tfail=%s\terr=%s\t%s\n' \
    "$spec" "$status" "$rc" "${passed:-0}" "${failed:-0}" "${errors:-0}" "$last" \
    >> "$OUT_DIR/results.tsv"
  echo "$status $spec"
}
export -f run_one
export ROOT OUT_DIR FILE_TIMEOUT

printf '%s\n' "${files[@]}" | xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {}

echo
echo "=== summary ==="
cut -f2 "$OUT_DIR/results.tsv" | sort | uniq -c | sort -rn
echo "results: $OUT_DIR/results.tsv"
