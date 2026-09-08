#!/usr/bin/env bash
# Shared paths for RVWMO litmus pipeline.
set -euo pipefail

LITMUS_WORK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEM5_ROOT="$(cd "${LITMUS_WORK}/.." && pwd)"
LITMUS_TESTS_ROOT="${LITMUS_TESTS_ROOT:-/ssdhome/maoweiming/xiangshan/litmus-tests-riscv}"
HERDTOOLS_BIN="${HERDTOOLS_BIN:-/ssdhome/maoweiming/xiangshan/.opam-root/default/bin}"
CAT_MODEL="${CAT_MODEL:-/ssdhome/maoweiming/xiangshan/herdtools7/herd/libdir/riscv.cat}"
XS_ENV_IMAGE="${XS_ENV_IMAGE:-ghcr.io/openxiangshan/xs-env:latest}"
GEM5_CONTAINER="${GEM5_CONTAINER:-gem5-build}"
GEM5_CFG="${GEM5_CFG:-configs/deprecated/example/se.py}"

export PATH="${HERDTOOLS_BIN}:${PATH}"

# Exit codes:
#   0  success (Observation line found)
#   1  usage / config error
#   2  litmus7 / cross-compile failure
#   3  gem5 simulation failure / panic
#   4  harness ran but Observation missing / unexpected
