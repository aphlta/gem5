# RVWMO litmus pipeline (Phases 0–5 MVP)

## Exit codes (`run_litmus_gem5.sh`)

| Code | Meaning |
|------|---------|
| 0 | Success; printed `Observation ...` |
| 1 | Usage / missing inputs |
| 2 | litmus7 or Docker cross-compile failed |
| 3 | gem5 panic / no log / hard failure |
| 4 | gem5 ran but no `Observation` line |

Harness non-zero exit with a printed Observation is treated as success.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/run_litmus_gem5.sh` | One litmus → generate/compile/run |
| `scripts/run_herd_r0.sh` | herd oracle for R0 |
| `scripts/run_r0_baseline.sh` | R0 Atomic or O3 table |
| `scripts/run_p2_gates.sh` | Phase-2 Never gates |
| `scripts/run_mvp_signoff.sh` | MVP signoff suite |

## Quick start

```bash
export PATH="/ssdhome/maoweiming/xiangshan/.opam-root/default/bin:$PATH"
cd /ssdhome/maoweiming/gem5/litmus-work

./scripts/run_herd_r0.sh
./scripts/run_litmus_gem5.sh \
  /ssdhome/maoweiming/xiangshan/litmus-tests-riscv/tests/non-mixed-size/BASIC_2_THREAD/SB.litmus \
  DerivO3CPU

./scripts/run_r0_baseline.sh AtomicSimpleCPU
./scripts/run_r0_baseline.sh DerivO3CPU
./scripts/run_p2_gates.sh
./scripts/run_mvp_signoff.sh
```

Requires: `gem5-build` container and `ghcr.io/openxiangshan/xs-env:latest`.

## Regression tiers

| Tier | When | Contents |
|------|------|----------|
| **R0** | every change | SB, MP, LB, MP+fence.rw.rws |
| **R1 / gates** | before merge | + SB+fence.rw.rws, HAND MP+fence.w.w+addr-rfi, AMO-FENCE, fence.tso |
| **R2** | weekly optional | IRIW samples (not automated in MVP) |

## Scale

- Dev: `SIZE_OF_TEST=50 NUMBER_OF_RUN=1`
- Pre-merge: e.g. `SIZE_OF_TEST=200 NUMBER_OF_RUN=5`

## CPU count

2-thread litmus: **`NUM_CPUS=4`** (default).

## Docs

- PDOCS: `docs/15-香山GEM5/RVWMO-MVP子集边界.md`
- Expected/gates under `expected/`
- Signoff archives under `mvp-signoff/`
