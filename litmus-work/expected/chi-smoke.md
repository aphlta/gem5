# CHI / Ruby smoke + IRIW notes

Generated: 2026-09-08

## ACQUIRE / RELEASE wiring (Classic-first)

- `aq` / `rl` on LR/SC/AMO set `Request::ACQUIRE` / `Request::RELEASE` on the memory microop (`amo.isa`).
- Micro-fences (WriteBarrier / ReadBarrier) remain for O3 MemDep / commit drain.
- `Request::isAcquire()` fixed to read `Flags` (same field ARM `memFlags` use); previously checked unused `cacheCoherenceFlags`.
- LSQ already requires RELEASE / LLSC stores to write back at SQ head (never weaker).

## CHI smoke command

```bash
# Needs ALL binary with RUBY_PROTOCOL_CHI (container often has build/ALL/gem5.opt)
USE_RUBY=1 RUBY_PROTOCOL=CHI GEM5_BIN_ALL=./build/ALL/gem5.opt \
  SIZE_OF_TEST=20 NUMBER_OF_RUN=1 \
  ./scripts/run_chi_smoke.sh
```

| Test | herd | gem5 CHI | Gate |
|------|------|----------|------|
| `SB.litmus` | Sometimes | *(run script)* | no panic + Observation |
| `MP+fence.rw.rws.litmus` | Never | *(run script)* | Must stay Never |

Status at Phase 6 land:

- Classic O3 path validated green (signoff).
- CHI smoke via ALL binary: use `RiscvO3CPU` (script auto-maps from `DerivO3CPU`).
- First attempt failed on `--cpu-type=DerivO3CPU` invalid under ALL; fixed in `run_litmus_gem5.sh`.
- CHI via ALL + `--protocol CHI` reaches `CHI_config.py` but hits
  `NameError: Cache_Controller is not defined` under MULTIPLE-protocol naming
  (needs stdlib CHI board or PROTOCOL=CHI dedicated build). Documented as tooling debt.

## IRIW / protocol notes

- Classic O3 + caches is strongly multi-copy-atomic; IRIW weak outcomes are rare/absent → often **过强债务** vs herd Sometimes.
- CHI may improve protocol visibility for ACQ/REL but can remain over-strong; **do not weaken** below herd Never.
- Compare IRIW samples via `./scripts/run_r2_suite.sh` on Classic; optional CHI column when smoke is green.
