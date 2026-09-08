#!/usr/bin/env bash
# Phase 6A.2: CHI (Ruby) smoke using ALL binary + --protocol CHI.
# Records expected/chi-smoke.md; never-leak fails the script.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
RUN="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"
OUT="${LITMUS_WORK}/expected/chi-smoke.md"
SIZE_OF_TEST="${SIZE_OF_TEST:-20}"
NUMBER_OF_RUN="${NUMBER_OF_RUN:-1}"
export SIZE_OF_TEST NUMBER_OF_RUN
export USE_RUBY=1
export RUBY_PROTOCOL="${RUBY_PROTOCOL:-CHI}"
export GEM5_BIN_ALL="${GEM5_BIN_ALL:-./build/ALL/gem5.opt}"
# CHI configs often want more dirs/l3; pass through EXTRA if needed.
export NUM_CPUS="${NUM_CPUS:-4}"

TESTS=(
  "${BASIC}/BASIC_2_THREAD/SB.litmus"
  "${BASIC}/BASIC_2_THREAD/MP+fence.rw.rws.litmus"
)

{
  echo "# CHI / Ruby smoke"
  echo
  echo "Generated: $(date -Iseconds)"
  echo "Binary: \`${GEM5_BIN_ALL}\` protocol=\`${RUBY_PROTOCOL}\`"
  echo "Scale: SIZE_OF_TEST=${SIZE_OF_TEST} NUMBER_OF_RUN=${NUMBER_OF_RUN}"
  echo
  echo "| Test | herd | gem5 CHI | Gate |"
  echo "|------|------|----------|------|"
} >"${OUT}"

FAIL=0
for f in "${TESTS[@]}"; do
  name="$(basename "$f")"
  echo "==== CHI smoke ${name} ====" >&2
  h="$(herd7 -model "${CAT_MODEL}" "$f" 2>/dev/null | grep '^Observation ' | tail -1 | awk '{print $3}')"
  set +e
  line="$("$RUN" "$f" DerivO3CPU 2>&1)"
  ec=$?
  set -e
  g="$(echo "$line" | grep '^Observation ' | tail -1 | awk '{print $3}' || true)"
  gate=OK
  if [[ ${ec} -ne 0 || -z "${g}" ]]; then
    gate=FAIL
    g="${g:-no-obs}"
    FAIL=1
  elif [[ "$h" == "Never" && "$g" != "Never" ]]; then
    gate=FAIL
    FAIL=1
  fi
  echo "| \`${name}\` | ${h} | **${g}** | ${gate} |" >>"${OUT}"
done

{
  echo
  echo "## IRIW notes"
  echo
  echo "- Classic O3 + caches is multi-copy-atomic enough that IRIW weak outcomes are rare/absent."
  echo "- CHI may still be over-strong vs herd Sometimes; treat unexplained Never as **过强债务**, not a leak."
  echo "- Compare with \`./scripts/run_r2_suite.sh\` IRIW samples on Classic; CHI column is best-effort smoke here."
  echo
  echo "## ACQUIRE/RELEASE"
  echo
  echo "- RISC-V \`aq\`/\`rl\` now set \`Request::ACQUIRE\`/\`RELEASE\` on LR/SC/AMO microops (see \`amo.isa\`)."
  echo "- \`Request::isAcquire()\` fixed to read Flags (same field ARM memFlags use)."
  echo "- LSQ already forces RELEASE stores to drain at SQ head (never weaker)."
} >>"${OUT}"

echo "wrote ${OUT}"
exit "${FAIL}"
