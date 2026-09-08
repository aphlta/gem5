# Debt scoreboard (Phase C)

Generated: 2026-09-08T17:50:15+08:00
Branch tip: `6e16f1728d` (`rvwmo-mvp`)
Model: `/ssdhome/maoweiming/xiangshan/herdtools7/herd/libdir/riscv.cat`
CPU: `DerivO3CPU`; scale `-s 200 -r 3`
Seed: `debt_scoreboard.seed`

## Summary

| Metric | Count |
|--------|------:|
| ok | 16 |
| over-strength debt | 8 |
| regression fail | 1 |
| skip | 0 |

Hard gate: any `regression fail` with herd=Never / gem5≠Never is a **Never leak**.

## KPI focus (Reduce targets)

- `BASIC_2_THREAD/MP.litmus`
- `BASIC_2_THREAD/LB.litmus`
- `harness/MP-fence-w-w.litmus` (when herd=Sometimes)

## Table

| Test | herd | gem5 | classification |
|------|------|------|----------------|
| `BASIC_2_THREAD/SB.litmus` | Sometimes | **FAIL** | regression fail |
| `BASIC_2_THREAD/MP.litmus` | Sometimes | **Sometimes** | ok |
| `BASIC_2_THREAD/LB.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/MP+fence.rw.rws.litmus` | Never | **Never** | ok |
| `harness/MP-fence-w-w.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/SB+fence.rw.rws.litmus` | Never | **Never** | ok |
| `BASIC_2_THREAD/LB+fence.rw.rws.litmus` | Never | **Never** | ok |
| `BASIC_2_THREAD/2+2W.litmus` | Sometimes | **Sometimes** | ok |
| `BASIC_2_THREAD/2+2W+fence.rw.rws.litmus` | Never | **Never** | ok |
| `BASIC_2_THREAD/R.litmus` | Sometimes | **Sometimes** | ok |
| `BASIC_2_THREAD/R+fence.rw.rws.litmus` | Never | **Never** | ok |
| `BASIC_2_THREAD/S.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/S+fence.rw.rws.litmus` | Never | **Never** | ok |
| `BASIC_2_THREAD/MP+fence.rw.rw+po.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/MP+po+fence.rw.rw.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/LB+fence.rw.rw+po.litmus` | Sometimes | **Never** | over-strength debt |
| `BASIC_2_THREAD/SB+fence.rw.rw+po.litmus` | Sometimes | **Sometimes** | ok |
| `SAFE/IRIW+addrs.litmus` | Never | **Never** | ok |
| `SAFE/IRIW+fence.rw.rws.litmus` | Never | **Never** | ok |
| `SAFE/IRIW+fence.r.rws.litmus` | Never | **Never** | ok |
| `SAFE/2+2W+fence.w.ws.litmus` | Never | **Never** | ok |
| `SAFE/2+2W+fence.rw.rws.litmus` | Never | **Never** | ok |
| `RELAX/PodWW/2+2W.litmus` | Sometimes | **Sometimes** | ok |
| `RELAX/PodWW/MP+po+fence.rw.rw.litmus` | Sometimes | **Never** | over-strength debt |
| `RELAX/PodWW/2+2W+fence.w.w+po.litmus` | Sometimes | **Never** | over-strength debt |

## Regenerate

```bash
cd /ssdhome/maoweiming/gem5/litmus-work
./scripts/run_debt_scoreboard.sh -s 200 -r 3
```

Skips: `logs/debt-scoreboard-skips.log`

Note: scripts auto-set `NUM_CPUS=2×#procs` (IRIW needs 8).
