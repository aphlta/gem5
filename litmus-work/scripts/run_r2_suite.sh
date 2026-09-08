#!/usr/bin/env bash
# Phase C R2 half-auto suite (~30–80 litmus): IRIW sample + fence diffs + seed.
#
# Usage:
#   ./scripts/run_r2_suite.sh [-s SIZE] [-r RUNS] [--max N] [--list-only]
#
# Behavior:
#   - Skips non-assemblable / build failures (logged), continues
#   - Never leak (herd Never, gem5 ≠ Never) ⇒ suite FAIL
#   - Over-strength debt is reported but does not fail R2 (measurement tier)
#   - Auto NUM_CPUS=2×#procs (IRIW → 8)
#
# Why: weekly optional expansion beyond R0/R1 without blocking on compile misses.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/litmus_classify.sh"

SIZE_OF_TEST="${SIZE_OF_TEST:-50}"
NUMBER_OF_RUN="${NUMBER_OF_RUN:-1}"
MAX_TESTS="${MAX_TESTS:-60}"
LIST_ONLY=0
CPU_TYPE="${CPU_TYPE:-DerivO3CPU}"
NON_MIXED="${LITMUS_TESTS_ROOT}/tests/non-mixed-size"
SEED_FILE="${LITMUS_WORK}/scripts/debt_scoreboard.seed"
RUN_GEM5="${LITMUS_WORK}/scripts/run_litmus_gem5.sh"
OUT_DIR="${LITMUS_WORK}/r2-runs"
SKIP_LOG="${LITMUS_WORK}/logs/r2-suite-skips.log"

usage() {
  cat <<EOF
usage: $0 [-s SIZE] [-r RUNS] [--max N] [--list-only] [--cpu CPU] [-h]
  -s / -r   harness scale (also via SIZE_OF_TEST / NUMBER_OF_RUN)
  --max N   cap suite size (default ${MAX_TESTS}; target band 30–80)
  --list-only  print selected paths and exit
Nightly example: $0 -s 200 -r 5 --max 80
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SIZE_OF_TEST="$2"; shift 2 ;;
    -r) NUMBER_OF_RUN="$2"; shift 2 ;;
    --max) MAX_TESTS="$2"; shift 2 ;;
    --list-only) LIST_ONLY=1; shift ;;
    --cpu) CPU_TYPE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

export SIZE_OF_TEST NUMBER_OF_RUN
mkdir -p "${LITMUS_WORK}/logs" "${OUT_DIR}"
REPORT="${OUT_DIR}/r2-$(date +%Y%m%d-%H%M%S).md"
: >"${SKIP_LOG}"

declare -a CANDIDATES=()
declare -A SEEN=()

add_cand() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  if litmus_should_skip "${f}"; then
    return 0
  fi
  if [[ -n "${SEEN[${f}]:-}" ]]; then
    return 0
  fi
  SEEN["${f}"]=1
  CANDIDATES+=("${f}")
}

while IFS= read -r entry; do
  [[ -z "${entry}" || "${entry}" =~ ^# ]] && continue
  add_cand "$(resolve_litmus_path "${entry}" "${NON_MIXED}" "${LITMUS_WORK}")"
done < <(grep -vE '^\s*(#|$)' "${SEED_FILE}")

while IFS= read -r f; do
  add_cand "${f}"
done < <(find "${NON_MIXED}/SAFE" -maxdepth 1 -type f -name 'IRIW*.litmus' 2>/dev/null | sort)

while IFS= read -r f; do
  add_cand "${f}"
done < <(find "${NON_MIXED}/BASIC_2_THREAD" -maxdepth 1 -type f -name '*fence*.litmus' 2>/dev/null | sort)

while IFS= read -r f; do
  base="$(basename "${f}")"
  [[ "${base}" == 3.* ]] && continue
  add_cand "${f}"
done < <(find "${NON_MIXED}/SAFE" -maxdepth 1 -type f \( -name 'MP+*.litmus' -o -name 'LB+*.litmus' -o -name 'SB+*.litmus' -o -name '2+2W+*fence*.litmus' \) 2>/dev/null | sort)

while IFS= read -r f; do
  add_cand "${f}"
done < <(find "${NON_MIXED}/RELAX/PodWW" -maxdepth 1 -type f -name '*.litmus' 2>/dev/null | sort)

if [[ ${#CANDIDATES[@]} -gt ${MAX_TESTS} ]]; then
  CANDIDATES=("${CANDIDATES[@]:0:${MAX_TESTS}}")
fi

n="${#CANDIDATES[@]}"
if [[ ${n} -lt 30 ]]; then
  echo "warning: only ${n} tests selected (want ≥30); check suite paths" >&2
fi

# Status on stderr so --list-only stdout is a clean path list for wc/xargs.
echo "==> R2 suite: ${n} tests, -s ${SIZE_OF_TEST} -r ${NUMBER_OF_RUN}" >&2

if [[ ${LIST_ONLY} -eq 1 ]]; then
  printf '%s\n' "${CANDIDATES[@]}"
  exit 0
fi

leak=0
debt=0
ok=0
skip=0
fail_other=0
rows=()

for f in "${CANDIDATES[@]}"; do
  rel="${f#"${NON_MIXED}"/}"
  if [[ "${f}" == "${LITMUS_WORK}"/* ]]; then
    rel="${f#"${LITMUS_WORK}"/}"
  fi
  name="$(basename "${f}" .litmus)"
  safe_name="${name//+/-}"
  safe_name="${safe_name//./-}"
  echo "==== R2 ${rel} ===="

  herd_log="${LITMUS_WORK}/logs/herd-r2-${safe_name}.log"
  herd7 -model "${CAT_MODEL}" "${f}" >"${herd_log}" 2>&1 || true
  herd_kind="$(obs_kind "$(cat "${herd_log}")")"
  if [[ -z "${herd_kind}" ]]; then
    echo "SKIP herd ${rel}" | tee -a "${SKIP_LOG}"
    skip=$((skip + 1))
    rows+=("| \`${rel}\` | — | — | skip (herd) |")
    continue
  fi

  NUM_CPUS="$(litmus_suggested_cpus "${f}")"
  export NUM_CPUS
  set +e
  gem5_out="$(NUM_CPUS="${NUM_CPUS}" "${RUN_GEM5}" "${f}" "${CPU_TYPE}" 2>&1)"
  gem5_ec=$?
  set -e

  if [[ ${gem5_ec} -eq 2 ]]; then
    echo "SKIP build ${rel}" | tee -a "${SKIP_LOG}"
    echo "${gem5_out}" >>"${SKIP_LOG}"
    skip=$((skip + 1))
    rows+=("| \`${rel}\` | ${herd_kind} | — | skip (build) |")
    continue
  fi

  if [[ ${gem5_ec} -ne 0 ]]; then
    echo "FAIL run ${rel} exit=${gem5_ec}" | tee -a "${SKIP_LOG}"
    fail_other=$((fail_other + 1))
    rows+=("| \`${rel}\` | ${herd_kind} | FAIL | regression fail |")
    continue
  fi

  gem5_kind="$(obs_kind "${gem5_out}")"
  class="$(classify_debt "${herd_kind}" "${gem5_kind}")"
  echo "${rel}: herd=${herd_kind} gem5=${gem5_kind} → ${class}"
  rows+=("| \`${rel}\` | ${herd_kind} | **${gem5_kind}** | ${class} |")

  case "${class}" in
    ok) ok=$((ok + 1)) ;;
    "over-strength debt") debt=$((debt + 1)) ;;
    "regression fail")
      if [[ "${herd_kind}" == "Never" && "${gem5_kind}" != "Never" ]]; then
        leak=$((leak + 1))
      else
        fail_other=$((fail_other + 1))
      fi
      ;;
  esac
done

gen_ts="$(date -Iseconds)"
{
  printf '%s\n' "# R2 suite report"
  printf '%s\n' ""
  printf '%s\n' "Generated: ${gen_ts}"
  printf '%s\n' "Scale: \`-s ${SIZE_OF_TEST} -r ${NUMBER_OF_RUN}\`; max=${MAX_TESTS}; ran=${n}"
  printf '%s\n' "CPU: \`${CPU_TYPE}\` (NUM_CPUS auto = 2×#procs)"
  printf '%s\n' ""
  printf '%s\n' "| Metric | Count |"
  printf '%s\n' "|--------|------:|"
  printf '%s\n' "| ok | ${ok} |"
  printf '%s\n' "| over-strength debt | ${debt} |"
  printf '%s\n' "| Never leak | ${leak} |"
  printf '%s\n' "| other fail | ${fail_other} |"
  printf '%s\n' "| skip | ${skip} |"
  printf '%s\n' ""
  printf '%s\n' "| Test | herd | gem5 | classification |"
  printf '%s\n' "|------|------|------|----------------|"
  for row in "${rows[@]}"; do
    printf '%s\n' "${row}"
  done
  printf '%s\n' ""
  printf '%s\n' "Skips: \`logs/r2-suite-skips.log\`"
  printf '%s\n' ""
  printf '%s\n' "Gate: **Never leak ⇒ fail** (exit 1)."
} >"${REPORT}"

ln -sfn "$(basename "${REPORT}")" "${OUT_DIR}/latest.md"
echo "wrote ${REPORT}"
echo "summary: ok=${ok} debt=${debt} leak=${leak} other_fail=${fail_other} skip=${skip}"

if [[ ${leak} -gt 0 ]]; then
  echo "error: Never leak detected (${leak})" >&2
  exit 1
fi
if [[ ${fail_other} -gt 0 ]]; then
  echo "error: non-leak failures (${fail_other})" >&2
  exit 1
fi
exit 0
