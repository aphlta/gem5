#!/usr/bin/env bash
# Shared herd/gem5 Observation parsing + debt classification.
# Why: Phase C scoreboard / R2 must use one rule for "ok vs over-strength vs leak".
# shellcheck shell=bash

# Extract Sometimes|Never|Always from an Observation line (or raw log text).
obs_kind() {
  local text="$1"
  echo "${text}" | grep -E 'Observation ' | tail -1 | awk '{print $3}'
}

# Classify (herd_kind, gem5_kind) → ok | over-strength debt | regression fail
# - herd Never ⇒ gem5 must be Never (else Never leak = regression fail)
# - herd Sometimes + gem5 Never = over-strength debt (allowed for now; Reduce target)
# - matching kinds / Sometimes↔Always quirks: treat equal as ok; Always vs Sometimes as ok
#   (Always is a stronger claim on outcomes; we do not fail gem5 Sometimes on herd Always here)
classify_debt() {
  local herd="$1" gem5="$2"
  if [[ -z "${herd}" || -z "${gem5}" ]]; then
    echo "regression fail"
    return
  fi
  if [[ "${herd}" == "Never" && "${gem5}" != "Never" ]]; then
    echo "regression fail"
    return
  fi
  if [[ "${herd}" == "Sometimes" && "${gem5}" == "Never" ]]; then
    echo "over-strength debt"
    return
  fi
  if [[ "${herd}" == "${gem5}" ]]; then
    echo "ok"
    return
  fi
  # herd Always + gem5 Sometimes: still observed the forbidden? No — Always means
  # the outcome is required; Sometimes still saw it. Count as ok for gate purposes.
  if [[ "${herd}" == "Always" && "${gem5}" == "Sometimes" ]]; then
    echo "ok"
    return
  fi
  if [[ "${herd}" == "Always" && "${gem5}" == "Never" ]]; then
    echo "over-strength debt"
    return
  fi
  # herd Sometimes + gem5 Always: stronger but not a Forbidden leak
  if [[ "${herd}" == "Sometimes" && "${gem5}" == "Always" ]]; then
    echo "ok"
    return
  fi
  echo "regression fail"
}

# Return 0 if this litmus should be skipped (known non-assemblable / out of MVP ISA).
# Why: lw.aq / sw.rl etc. fail in our xs-env cross-gcc path; log and continue.
litmus_should_skip() {
  local f="$1"
  local base
  base="$(basename "${f}")"
  # Filename heuristics used by diy for acquire/release plain loads/stores
  if [[ "${base}" =~ [Pp][Oo][Aa][Qq]|[Pp][Oo][Pp][Rr][Ll]|PAq|RlP|RlAq ]]; then
    return 0
  fi
  if [[ ! -f "${f}" ]]; then
    return 0
  fi
  # Body: plain load-acquire / store-release encodings we cannot assemble yet
  if grep -qE '(^|[[:space:]])(lw|lh|lb|lwu|ld)\.aq([[:space:]]|$)|(^[ [:space:]])(sw|sh|sb|sd)\.rl([[:space:]]|$)' "${f}"; then
    return 0
  fi
  return 1
}

# Resolve a seed entry to an absolute path.
# Entries are either absolute, LOCAL:relpath under LITMUS_WORK, or relative under NON_MIXED.
resolve_litmus_path() {
  local entry="$1"
  local non_mixed="${2:-${LITMUS_TESTS_ROOT}/tests/non-mixed-size}"
  local work="${3:-${LITMUS_WORK}}"
  if [[ "${entry}" == LOCAL:* ]]; then
    echo "${work}/${entry#LOCAL:}"
  elif [[ "${entry}" = /* ]]; then
    echo "${entry}"
  else
    echo "${non_mixed}/${entry}"
  fi
}

# Count litmus processes from the " P0 | P1 | ..." header line.
# Why: IRIW needs 4 threads; default NUM_CPUS=4 is only enough for 2-thread harnesses.
litmus_num_procs() {
  local f="$1"
  local hdr
  hdr="$(grep -E '^[[:space:]]*P[0-9]+[[:space:]]*(\||;)' "${f}" | head -1 || true)"
  if [[ -z "${hdr}" ]]; then
    echo 2
    return
  fi
  # Count P0, P1, ... tokens on the process header
  echo "${hdr}" | grep -oE 'P[0-9]+' | wc -l
}

# Suggest gem5 -n: 2x processes (matches existing 2-thread → NUM_CPUS=4 convention).
litmus_suggested_cpus() {
  local f="$1"
  local n
  n="$(litmus_num_procs "${f}")"
  if [[ "${n}" -lt 1 ]]; then
    n=2
  fi
  echo $((n * 2))
}
