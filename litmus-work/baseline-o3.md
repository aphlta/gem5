# R0 gem5 baseline (DerivO3CPU) — Phase 0 (pre-decoder change)

Generated: 2026-09-08T14:12:40+08:00
Config: SE `-n 4`, mem 256MB; O3 uses `--caches`.
Harness scale: SIZE_OF_TEST=50 NUMBER_OF_RUN=1
Gate note: use larger `-s/-r` before merge; this table is the development baseline.

| Test | Observation | Log |
|------|-------------|-----|
| `SB.litmus` | **Sometimes** (`Observation SB Sometimes 27 23`) | logs/SB-DerivO3CPU.log |
| `MP.litmus` | **Never** (`Observation MP Never 0 50`) | logs/MP-DerivO3CPU.log |
| `LB.litmus` | **Never** (`Observation LB Never 0 50`) | logs/LB-DerivO3CPU.log |
| `MP+fence.rw.rws.litmus` | **Never** (`Observation MP+fence.rw.rws Never 0 50`) | logs/MP-fence-rw-rws-DerivO3CPU.log |
