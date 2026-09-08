# Ztso vs RVWMO (DerivO3CPU)

Generated: 2026-09-08  
Scale: mixed (see notes)  
Ztso path: `ZTSO=1` → `extra_extensions=["Ztso"]` + `RiscvO3CPU.syncNeedsTSOFromZtso()` ⇒ `needsTSO=True`

| Test | herd | gem5 RVWMO | gem5 Ztso | Note |
|------|------|------------|-----------|------|
| `SB.litmus` | Sometimes | **Sometimes** (45/50) | **Never** (0/50) | Ztso path stronger than real TSO for SB (debt); still no Never-leak |
| `MP.litmus` | Sometimes | **Sometimes** (194/600) | **Never** (0/200) | Ztso stronger (expected: kills PodWW reorder) |
| `MP+fence.rw.rws.litmus` | Never | **Never** | **Never** | Never gate OK both modes |
| `SB+fence.rw.rws.litmus` | Never | **Never** | (same gate) | Never gate OK |

Regenerate: `./scripts/run_ztso_dual.sh`
