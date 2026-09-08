#!/usr/bin/env bash
# Generate + cross-compile + run one .litmus under gem5 SE.
#
# Usage:
#   run_litmus_gem5.sh <path-to.litmus> [AtomicSimpleCPU|DerivO3CPU] [extra-gem5-args...]
#
# Env:
#   SIZE_OF_TEST / NUMBER_OF_RUN  (default 50 / 1)
#   NUM_CPUS                     (default 4)
#   MEM_SIZE                     (default 256MB)
#
# Exit codes: see scripts/common.sh
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <litmus> [cpu-type] [extra gem5 args...]" >&2
  exit 1
fi

LITMUS_FILE="$(readlink -f "$1")"
CPU_TYPE="${2:-DerivO3CPU}"
shift $(( $# >= 2 ? 2 : 1 )) || true
EXTRA_GEM5_ARGS=("$@")

SIZE_OF_TEST="${SIZE_OF_TEST:-50}"
NUMBER_OF_RUN="${NUMBER_OF_RUN:-1}"
NUM_CPUS="${NUM_CPUS:-4}"
MEM_SIZE="${MEM_SIZE:-256MB}"

if [[ ! -f "${LITMUS_FILE}" ]]; then
  echo "error: litmus not found: ${LITMUS_FILE}" >&2
  exit 1
fi

NAME="$(basename "${LITMUS_FILE}" .litmus)"
# Sanitize for directory names
SAFE_NAME="${NAME//+/-}"
SAFE_NAME="${SAFE_NAME//./-}"
HARNESS_DIR="${LITMUS_WORK}/harness/${SAFE_NAME}"
LOG_DIR="${LITMUS_WORK}/logs"
mkdir -p "${HARNESS_DIR}" "${LOG_DIR}"

CFG="${LITMUS_WORK}/riscv-gem5.cfg"
GEN_LOG="${LOG_DIR}/${SAFE_NAME}-gen.log"
BUILD_LOG="${LOG_DIR}/${SAFE_NAME}-build.log"
RUN_LOG="${LOG_DIR}/${SAFE_NAME}-${CPU_TYPE}.log"
M5OUT="${LITMUS_WORK}/m5out/${SAFE_NAME}-${CPU_TYPE}"

echo "==> [1/3] litmus7 generate: ${NAME}"
rm -rf "${HARNESS_DIR:?}/"*
mkdir -p "${HARNESS_DIR}"
if ! litmus7 -mach "${CFG}" -cross "${HARNESS_DIR}" \
    -s "${SIZE_OF_TEST}" -r "${NUMBER_OF_RUN}" \
    "${LITMUS_FILE}" >"${GEN_LOG}" 2>&1; then
  echo "error: litmus7 failed; see ${GEN_LOG}" >&2
  exit 2
fi

echo "==> [2/3] cross-compile in ${XS_ENV_IMAGE}"
if ! docker run --rm \
    -v "${HARNESS_DIR}:/work" \
    -w /work/src \
    "${XS_ENV_IMAGE}" \
    bash -lc 'make clean >/dev/null 2>&1 || true; make GCC=riscv64-linux-gnu-gcc' \
    >"${BUILD_LOG}" 2>&1; then
  echo "error: cross-compile failed; see ${BUILD_LOG}" >&2
  exit 2
fi

if [[ ! -x "${HARNESS_DIR}/src/run.exe" ]]; then
  echo "error: run.exe missing after build" >&2
  exit 2
fi

CACHE_ARGS=()
if [[ "${CPU_TYPE}" == "DerivO3CPU" || "${CPU_TYPE}" == *O3* ]]; then
  CACHE_ARGS=(--caches)
fi

echo "==> [3/3] gem5 SE ${CPU_TYPE} -n ${NUM_CPUS} (container ${GEM5_CONTAINER})"
CONT_BIN="/gem5/litmus-work/harness/${SAFE_NAME}/src/run.exe"
CONT_OUT="/gem5/litmus-work/m5out/${SAFE_NAME}-${CPU_TYPE}"
CONT_LOG="/gem5/litmus-work/logs/${SAFE_NAME}-${CPU_TYPE}.log"
CONT_OUT_PARENT="$(dirname "${CONT_OUT}")"
CONT_LOG_PARENT="$(dirname "${CONT_LOG}")"
CACHE_STR="${CACHE_ARGS[*]-}"
EXTRA_STR="${EXTRA_GEM5_ARGS[*]-}"

set +e
docker exec "${GEM5_CONTAINER}" env \
  CONT_OUT="${CONT_OUT}" CONT_OUT_PARENT="${CONT_OUT_PARENT}" \
  CONT_LOG="${CONT_LOG}" CONT_LOG_PARENT="${CONT_LOG_PARENT}" \
  CONT_BIN="${CONT_BIN}" GEM5_CFG="${GEM5_CFG}" \
  NUM_CPUS="${NUM_CPUS}" CPU_TYPE="${CPU_TYPE}" MEM_SIZE="${MEM_SIZE}" \
  CACHE_STR="${CACHE_STR}" EXTRA_STR="${EXTRA_STR}" \
  bash -lc '
set -e
cd /gem5
rm -rf "$CONT_OUT"
mkdir -p "$CONT_OUT_PARENT" "$CONT_LOG_PARENT"
# shellcheck disable=SC2086
./build/RISCV/gem5.opt --outdir="$CONT_OUT" "$GEM5_CFG" \
  -n "$NUM_CPUS" --cpu-type="$CPU_TYPE" $CACHE_STR \
  -c "$CONT_BIN" --mem-size="$MEM_SIZE" $EXTRA_STR \
  >"$CONT_LOG" 2>&1
'
GEM5_EC=$?
set -e

if [[ ! -f "${RUN_LOG}" ]]; then
  echo "error: gem5 log missing: ${RUN_LOG}" >&2
  exit 3
fi

if grep -qE 'panic:|fatal:|Panic' "${RUN_LOG}"; then
  echo "error: gem5 panic/fatal; see ${RUN_LOG}" >&2
  exit 3
fi

if [[ ${GEM5_EC} -ne 0 ]]; then
  # Harness may exit non-zero while still printing Observation; check first.
  if ! grep -q 'Observation ' "${RUN_LOG}"; then
    echo "error: gem5 exit ${GEM5_EC} and no Observation; see ${RUN_LOG}" >&2
    exit 3
  fi
fi

OBS_LINE="$(grep -E '^Observation ' "${RUN_LOG}" | tail -1 || true)"
if [[ -z "${OBS_LINE}" ]]; then
  echo "error: Observation line not found; see ${RUN_LOG}" >&2
  exit 4
fi

echo "${OBS_LINE}"
echo "log: ${RUN_LOG}"
exit 0
