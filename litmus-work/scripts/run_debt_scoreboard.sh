#!/usr/bin/env bash
# Phase C: regenerate expected/debt-scoreboard.md (herd | gem5 | classification).
#
# Usage:
#   ./scripts/run_debt_scoreboard.sh [-s SIZE] [-r RUNS] [--seed FILE] [--cpu TYPE]
#
# Classification (English labels for stable scripting):
#   ok                 — matches never-weaker gate expectations
#   over-strength debt — herd Sometimes/Always but gem5 Never (Reduce backlog)
#   regression fail    — Never leak, missing Observation, or hard run failure
#
# Why: automates the debt baseline so Reduce can measure MP/LB progress without
# hand-edited tables. Avoid `...` inside double-quoted echo (bash command subst).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/litmus_classify.sh"

SIZE_OF_TEST="${SIZE_OF_TEST:-50}"
NUMBER_OF_RUN="${NUMBER_OF_RUN:-1}"
CPU_TYPE="${CPU_TYPE:-DerivO3CPU}"
SEED_FILE="${LITMUS_WORK}/scripts/debt_scoreboard.seed"
OUT="${LITMUS_WORK}/expected/debt-scoreboard.md"
SKIP_LOG="${LITMUS_WORK}/logs/debt-scoreboard-skips.log"
NON_MIXED="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
RUN_GEM5="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"

usage() {
  cat <<EOF
usage: $0 [-s SIZE] [-r RUNS] [--seed FILE] [--cpu CPU] [-h]
  -s SIZE   litmus7 SIZE_OF_TEST (default ${SIZE_OF_TEST})
  -r RUNS   litmus7 NUMBER_OF_RUN (default ${NUMBER_OF_RUN})
  --seed F  seed list (default scripts/debt_scoreboard.seed)
  --cpu T   gem5 CPU (default DerivO3CPU)
Env SIZE_OF_TEST / NUMBER_OF_RUN also accepted.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SIZE_OF_TEST="$2"; shift 2 ;;
    -r) NUMBER_OF_RUN="$2"; shift 2 ;;
    --seed) SEED_FILE="$2"; shift 2 ;;
    --cpu) CPU_TYPE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

export SIZE_OF_TEST NUMBER_OF_RUN
mkdir -p "${LITMUS_WORK}/expected" "${LITMUS_WORK}/logs"
: >"${SKIP_LOG}"

if [[ ! -f "${SEED_FILE}" ]]; then
  echo "error: seed file missing: ${SEED_FILE}" >&2
  exit 1
fi

mapfile -t SEED_ENTRIES < <(grep -vE '^\s*(#|$)' "${SEED_FILE}")

debt_count=0
ok_count=0
fail_count=0
skip_count=0
rows=()

run_herd() {
  local f="$1" log="$2"
  herd7 -model "${CAT_MODEL}" "${f}" >"${log}" 2>&1 || true
  obs_kind "$(cat "${log}")"
}

echo "==> debt scoreboard: ${#SEED_ENTRIES[@]} seed entries, -s ${SIZE_OF_TEST} -r ${NUMBER_OF_RUN}"

for entry in "${SEED_ENTRIES[@]}"; do
  f="$(resolve_litmus_path "${entry}" "${NON_MIXED}" "${LITMUS_WORK}")"
  name="$(basename "${f}" .litmus)"
  rel="${entry}"
  if [[ "${entry}" == LOCAL:* ]]; then
    rel="${entry#LOCAL:}"
  fi

  if [[ ! -f "${f}" ]]; then
    echo "SKIP missing ${rel}" | tee -a "${SKIP_LOG}"
    skip_count=$((skip_count + 1))
    rows+=("| \`${rel}\` | — | — | skip (missing) |")
    continue
  fi

  if litmus_should_skip "${f}"; then
    echo "SKIP non-assemblable ${rel}" | tee -a "${SKIP_LOG}"
    skip_count=$((skip_count + 1))
    rows+=("| \`${rel}\` | — | — | skip (non-assemblable) |")
    continue
  fi

  echo "==== ${rel} ===="
  # Sanitize log name without relying on nested parameter expansion quirks
  safe_name="${name//+/-}"
  safe_name="${safe_name//./-}"
  herd_log="${LITMUS_WORK}/logs/herd-debt-${safe_name}.log"
  herd_kind="$(run_herd "${f}" "${herd_log}")"
  if [[ -z "${herd_kind}" ]]; then
    echo "SKIP herd failed ${rel}" | tee -a "${SKIP_LOG}"
    skip_count=$((skip_count + 1))
    rows+=("| \`${rel}\` | — | — | skip (herd) |")
    continue
  fi

  # Scale -n with litmus thread count (IRIW=4 → NUM_CPUS=8).
  NUM_CPUS="$(litmus_suggested_cpus "${f}")"
  export NUM_CPUS

  gem5_kind=""
  class=""
  set +e
  gem5_out="$(NUM_CPUS="${NUM_CPUS}" "${RUN_GEM5}" "${f}" "${CPU_TYPE}" 2>&1)"
  gem5_ec=$?
  set -e
  if [[ ${gem5_ec} -eq 2 ]]; then
    echo "SKIP build ${rel} (exit 2)" | tee -a "${SKIP_LOG}"
    echo "${gem5_out}" >>"${SKIP_LOG}"
    skip_count=$((skip_count + 1))
    rows+=("| \`${rel}\` | ${herd_kind} | — | skip (build) |")
    continue
  fi
  if [[ ${gem5_ec} -ne 0 ]]; then
    gem5_kind="FAIL"
    class="regression fail"
    fail_count=$((fail_count + 1))
  else
    gem5_kind="$(obs_kind "${gem5_out}")"
    class="$(classify_debt "${herd_kind}" "${gem5_kind}")"
    case "${class}" in
      ok) ok_count=$((ok_count + 1)) ;;
      "over-strength debt") debt_count=$((debt_count + 1)) ;;
      *) fail_count=$((fail_count + 1)) ;;
    esac
  fi

  echo "${rel}: herd=${herd_kind} gem5=${gem5_kind} → ${class}"
  rows+=("| \`${rel}\` | ${herd_kind} | **${gem5_kind}** | ${class} |")
done

branch_tip="$(cd "${GEM5_ROOT}" && git rev-parse --short HEAD)"
branch_name="$(cd "${GEM5_ROOT}" && git branch --show-current)"
seed_base="$(basename "${SEED_FILE}")"
gen_ts="$(date -Iseconds)"

# Write markdown via printf to avoid bash `command` substitution on backticks.
{
  printf '%s\n' "# Debt scoreboard (Phase C)"
  printf '%s\n' ""
  printf '%s\n' "Generated: ${gen_ts}"
  printf '%s\n' "Branch tip: \`${branch_tip}\` (\`${branch_name}\`)"
  printf '%s\n' "Model: \`${CAT_MODEL}\`"
  printf '%s\n' "CPU: \`${CPU_TYPE}\`; scale \`-s ${SIZE_OF_TEST} -r ${NUMBER_OF_RUN}\`"
  printf '%s\n' "Seed: \`${seed_base}\`"
  printf '%s\n' ""
  printf '%s\n' "## Summary"
  printf '%s\n' ""
  printf '%s\n' "| Metric | Count |"
  printf '%s\n' "|--------|------:|"
  printf '%s\n' "| ok | ${ok_count} |"
  printf '%s\n' "| over-strength debt | ${debt_count} |"
  printf '%s\n' "| regression fail | ${fail_count} |"
  printf '%s\n' "| skip | ${skip_count} |"
  printf '%s\n' ""
  printf '%s\n' "Hard gate: any \`regression fail\` with herd=Never / gem5≠Never is a **Never leak**."
  printf '%s\n' ""
  printf '%s\n' "## KPI focus (Reduce targets)"
  printf '%s\n' ""
  printf '%s\n' "- \`BASIC_2_THREAD/MP.litmus\`"
  printf '%s\n' "- \`BASIC_2_THREAD/LB.litmus\`"
  printf '%s\n' "- \`harness/MP-fence-w-w.litmus\` (when herd=Sometimes)"
  printf '%s\n' ""
  printf '%s\n' "## Table"
  printf '%s\n' ""
  printf '%s\n' "| Test | herd | gem5 | classification |"
  printf '%s\n' "|------|------|------|----------------|"
  for row in "${rows[@]}"; do
    printf '%s\n' "${row}"
  done
  printf '%s\n' ""
  printf '%s\n' "## Regenerate"
  printf '%s\n' ""
  printf '%s\n' '```bash'
  printf '%s\n' "cd ${LITMUS_WORK}"
  printf '%s\n' "./scripts/run_debt_scoreboard.sh -s ${SIZE_OF_TEST} -r ${NUMBER_OF_RUN}"
  printf '%s\n' '```'
  printf '%s\n' ""
  printf '%s\n' "Skips: \`logs/debt-scoreboard-skips.log\`"
  printf '%s\n' ""
  printf '%s\n' "Note: scripts auto-set \`NUM_CPUS=2×#procs\` (IRIW needs 8)."
} >"${OUT}"

echo
echo "wrote ${OUT}"
echo "summary: ok=${ok_count} over-strength debt=${debt_count} regression fail=${fail_count} skip=${skip_count}"

if [[ ${fail_count} -gt 0 ]]; then
  exit 1
fi
exit 0
