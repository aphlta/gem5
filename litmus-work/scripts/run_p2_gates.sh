#!/usr/bin/env bash
# Run Phase-2 Never gates + contrast on O3.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
OUT="${LITMUS_WORK}/expected/p2-gate-results.md"
RUN="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"

{
  echo "# Phase 2 gate results (DerivO3CPU)"
  echo
  echo "Generated: $(date -Iseconds)"
  echo
  echo "| Test | herd | gem5 O3 | Gate |"
  echo "|------|------|---------|------|"
} >"${OUT}"

run_one() {
  local file="$1" herd_exp="$2"
  local name base obs kind gate
  name="$(basename "$file")"
  echo "==== $name ====" >&2
  obs="$("$RUN" "$file" DerivO3CPU | grep '^Observation ' | tail -1)"
  kind="$(echo "$obs" | awk '{print $3}')"
  gate=OK
  if [[ "$herd_exp" == "Never" && "$kind" != "Never" ]]; then
    gate=FAIL
  fi
  echo "| \`$name\` | $herd_exp | **$kind** | $gate |" >>"${OUT}"
  echo "$obs"
  [[ "$gate" == "OK" ]]
}

FAIL=0
run_one "$BASIC/BASIC_2_THREAD/MP+fence.rw.rws.litmus" Never || FAIL=1
run_one "$BASIC/BASIC_2_THREAD/SB+fence.rw.rws.litmus" Never || FAIL=1
run_one "$BASIC/HAND/MP+fence.w.w+addr-rfi.litmus" Never || FAIL=1
run_one "$BASIC/BASIC_2_THREAD/SB.litmus" Sometimes || true
run_one "$BASIC/BASIC_2_THREAD/MP.litmus" Sometimes || true
run_one "${LITMUS_WORK}/harness/MP-fence-w-w.litmus" Sometimes || true

echo "wrote ${OUT}"
exit "$FAIL"
