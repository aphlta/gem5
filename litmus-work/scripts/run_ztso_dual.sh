#!/usr/bin/env bash
# Phase 6B: dual-mode RVWMO vs Ztso litmus table → expected/ztso-vs-rvwmo.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
RUN="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"
OUT="${LITMUS_WORK}/expected/ztso-vs-rvwmo.md"
SIZE_OF_TEST="${SIZE_OF_TEST:-50}"
NUMBER_OF_RUN="${NUMBER_OF_RUN:-1}"
export SIZE_OF_TEST NUMBER_OF_RUN

TESTS=(
  "${BASIC}/BASIC_2_THREAD/SB.litmus"
  "${BASIC}/BASIC_2_THREAD/MP.litmus"
  "${BASIC}/BASIC_2_THREAD/MP+fence.rw.rws.litmus"
  "${BASIC}/BASIC_2_THREAD/SB+fence.rw.rws.litmus"
)

{
  echo "# Ztso vs RVWMO (DerivO3CPU)"
  echo
  echo "Generated: $(date -Iseconds)"
  echo "Scale: SIZE_OF_TEST=${SIZE_OF_TEST} NUMBER_OF_RUN=${NUMBER_OF_RUN}"
  echo "Ztso path: \`ZTSO=1\` → \`extra_extensions=[Ztso]\` + \`needsTSO=True\` binding."
  echo
  echo "| Test | herd | gem5 RVWMO | gem5 Ztso | Note |"
  echo "|------|------|------------|-----------|------|"
} >"${OUT}"

for f in "${TESTS[@]}"; do
  name="$(basename "$f")"
  echo "==== dual ${name} ====" >&2
  h="$(herd7 -model "${CAT_MODEL}" "$f" 2>/dev/null | grep '^Observation ' | tail -1 | awk '{print $3}')"
  rv="$("$RUN" "$f" DerivO3CPU | grep '^Observation ' | tail -1 | awk '{print $3}')"
  zt="$(ZTSO=1 "$RUN" "$f" DerivO3CPU | grep '^Observation ' | tail -1 | awk '{print $3}')"
  note=""
  if [[ "$h" == "Never" && ( "$rv" != "Never" || "$zt" != "Never" ) ]]; then
    note="NEVER-LEAK"
  elif [[ "$rv" == "Sometimes" && "$zt" == "Never" ]]; then
    note="Ztso stronger (expected for weak outcomes)"
  elif [[ "$rv" == "$zt" ]]; then
    note="same"
  fi
  echo "| \`${name}\` | **${h}** | **${rv}** | **${zt}** | ${note} |" >>"${OUT}"
done

echo "wrote ${OUT}"
