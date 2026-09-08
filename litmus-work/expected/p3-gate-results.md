# Phase 3 aq/rl gate results

| Test | herd | gem5 O3 | Gate |
|------|------|---------|------|
| `AMO-FENCE.litmus` | Never | **Never** | OK |
| `SB.litmus` | Sometimes | **Sometimes** | OK |
| `MP+fence.rw.rws` | Never | **Never** | OK |

Note: `RelAcq_2_THREAD` lw.aq/sw.rl harnesses failed to cross-assemble; AMO-FENCE covers aq.rl micro-fence path.
