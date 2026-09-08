#!/usr/bin/env bash
# MVP signoff: R0 Never gates + SB Sometimes + key R1 Never + AMO-FENCE + fence.tso
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
BASIC="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
RUN="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"
OUTDIR="${LITMUS_WORK}/mvp-signoff"
mkdir -p "${OUTDIR}"
OUT="${OUTDIR}/signoff-$(date +%Y%m%d).md"

{
  echo "# MVP signoff"
  echo
  echo "Generated: $(date -Iseconds)"
  echo "Branch tip: $(cd "${GEM5_ROOT}" && git rev-parse --short HEAD) ($(cd "${GEM5_ROOT}" && git branch --show-current))"
  echo
  echo "| Test | Expected | gem5 | Gate |"
  echo "|------|----------|------|------|"
} >"${OUT}"

gate_row() {
  local file="$1" expect="$2"
  local name obs kind gate
  name="$(basename "$file")"
  obs="$("$RUN" "$file" DerivO3CPU | grep '^Observation ' | tail -1 || true)"
  kind="$(echo "${obs}" | awk '{print $3}')"
  gate=OK
  if [[ "${expect}" == "Never" && "${kind}" != "Never" ]]; then gate=FAIL; fi
  if [[ "${expect}" == "Sometimes" && "${kind}" != "Sometimes" ]]; then gate=WARN; fi
  echo "| \`${name}\` | ${expect} | **${kind}** | ${gate} |" >>"${OUT}"
  echo "${name}: ${obs} [${gate}]"
  [[ "${gate}" != "FAIL" ]]
}

FAIL=0
gate_row "${BASIC}/BASIC_2_THREAD/SB.litmus" Sometimes || FAIL=1
gate_row "${BASIC}/BASIC_2_THREAD/MP+fence.rw.rws.litmus" Never || FAIL=1
gate_row "${BASIC}/BASIC_2_THREAD/SB+fence.rw.rws.litmus" Never || FAIL=1
gate_row "${BASIC}/HAND/MP+fence.w.w+addr-rfi.litmus" Never || FAIL=1
gate_row "${BASIC}/HAND/AMO-FENCE.litmus" Never || FAIL=1
gate_row "${BASIC}/HAND/MP+fence.w.w+fence.tso.litmus" Never || FAIL=1

cp "${OUT}" "${OUTDIR}/latest.md"
echo "wrote ${OUT}"
exit "${FAIL}"
