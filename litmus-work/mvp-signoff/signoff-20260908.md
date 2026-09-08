# MVP signoff

Generated: 2026-09-08T17:47:16+08:00
Branch tip: 6e16f1728d (rvwmo-mvp)

| Test | Expected | gem5 | Gate |
|------|----------|------|------|
| `SB.litmus` | Sometimes | **Sometimes** | OK |
| `MP+fence.rw.rws.litmus` | Never | **Never** | OK |
| `SB+fence.rw.rws.litmus` | Never | **Never** | OK |
| `MP+fence.w.w+addr-rfi.litmus` | Never | **Never** | OK |
| `AMO-FENCE.litmus` | Never | **Never** | OK |
| `MP+fence.w.w+fence.tso.litmus` | Never | **Never** | OK |
