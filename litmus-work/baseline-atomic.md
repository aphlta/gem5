# R0 gem5 baseline (AtomicSimpleCPU)

Generated: 2026-09-08T14:12:26+08:00
Config: SE `-n 4`, mem 256MB; O3 uses `--caches`.
Harness scale: SIZE_OF_TEST=50 NUMBER_OF_RUN=1
Gate note: use larger `-s/-r` before merge; this table is the development baseline.

| Test | Observation | Log |
|------|-------------|-----|
| `SB.litmus` | **Never** (`Observation SB Never 0 50`) | logs/SB-AtomicSimpleCPU.log |
| `MP.litmus` | **Never** (`Observation MP Never 0 50`) | logs/MP-AtomicSimpleCPU.log |
| `LB.litmus` | **Never** (`Observation LB Never 0 50`) | logs/LB-AtomicSimpleCPU.log |
| `MP+fence.rw.rws.litmus` | **Never** (`Observation MP+fence.rw.rws Never 0 50`) | logs/MP-fence-rw-rws-AtomicSimpleCPU.log |
