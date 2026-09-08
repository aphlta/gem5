#!/usr/bin/env bash
# Run R0 suite on given CPU; write baseline-*.md
# Usage: run_r0_baseline.sh AtomicSimpleCPU|DerivO3CPU
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

CPU_TYPE="${1:-AtomicSimpleCPU}"
BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size/BASIC_2_THREAD"
TESTS=(SB.litmus MP.litmus LB.litmus MP+fence.rw.rws.litmus)

if [[ "${CPU_TYPE}" == "AtomicSimpleCPU" ]]; then
  OUT="${LITMUS_WORK}/baseline-atomic.md"
else
  OUT="${LITMUS_WORK}/baseline-o3.md"
fi

{
  echo "# R0 gem5 baseline (${CPU_TYPE})"
  echo
  echo "Generated: $(date -Iseconds)"
  echo "Config: SE \`-n 4\`, mem 256MB; O3 uses \`--caches\`."
  echo "Harness scale: SIZE_OF_TEST=${SIZE_OF_TEST:-50} NUMBER_OF_RUN=${NUMBER_OF_RUN:-1}"
  echo "Gate note: use larger \`-s/-r\` before merge; this table is the development baseline."
  echo
  echo "| Test | Observation | Log |"
  echo "|------|-------------|-----|"
} >"${OUT}"

FAIL=0
for t in "${TESTS[@]}"; do
  echo "==== ${t} @ ${CPU_TYPE} ===="
  if out_line="$("${LITMUS_WORK}/scripts/run_litmus_gem5.sh" "${BASIC}/${t}" "${CPU_TYPE}")"; then
    obs="$(echo "${out_line}" | grep '^Observation ' | tail -1)"
    kind="$(echo "${obs}" | awk '{print $3}')"
    safe="${t%.litmus}"
    safe="${safe//+/-}"; safe="${safe//./-}"
    log="logs/${safe}-${CPU_TYPE}.log"
    echo "| \`${t}\` | **${kind}** (\`${obs}\`) | ${log} |" >>"${OUT}"
  else
    ec=$?
    echo "| \`${t}\` | **FAIL** (exit ${ec}) | see logs/ |" >>"${OUT}"
    FAIL=1
  fi
done

echo "wrote ${OUT}"
exit "${FAIL}"
