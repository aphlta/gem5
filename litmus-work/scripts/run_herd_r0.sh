#!/usr/bin/env bash
# Run herd7 on R0 suite; write expected/r0.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size/BASIC_2_THREAD"
OUT="${LITMUS_WORK}/expected/r0.md"
mkdir -p "$(dirname "${OUT}")"

TESTS=(SB.litmus MP.litmus LB.litmus MP+fence.rw.rws.litmus)

{
  echo "# R0 herd expectations (riscv.cat)"
  echo
  echo "Generated: $(date -Iseconds)"
  echo "Model: \`${CAT_MODEL}\`"
  echo
  echo "| Test | Observation | Condition snippet |"
  echo "|------|-------------|-------------------|"
} >"${OUT}"

for t in "${TESTS[@]}"; do
  f="${BASIC}/${t}"
  log="${LITMUS_WORK}/logs/herd-r0-${t%.litmus}.log"
  mkdir -p "$(dirname "${log}")"
  herd7 -model "${CAT_MODEL}" "${f}" >"${log}" 2>&1
  obs="$(grep -E '^Observation ' "${log}" | tail -1)"
  # Extract Sometimes/Never/Always token
  kind="$(echo "${obs}" | awk '{print $3}')"
  cond="$(grep -E '^Condition |^exists' "${log}" | head -1 | tr '|' '/')"
  echo "| \`${t}\` | **${kind}** | ${cond} |" >>"${OUT}"
  echo "${t}: ${obs}"
done

echo "wrote ${OUT}"
