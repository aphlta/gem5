# Phase 6 Reduce confirmation

## MP Sometimes (achieved)

```
SIZE_OF_TEST=200 NUMBER_OF_RUN=3
Observation MP Sometimes 194 406
```

Mechanism: `lsq_unit.cc` — when `!needsTSO`, hold oldest canWB store up to 8 cycles
while a younger uncommitted store sits in SQ, then prefer youngest non-overlapping
ready store for writeback (PodWW). Same-address / RELEASE / LLSC stay ordered;
WriteBarrier commit still drains SQ.

## LB (remaining debt)

```
SIZE_OF_TEST=100 NUMBER_OF_RUN=2
Observation LB Never 0 200
```

Root cause: in-order ROB commit prevents true load-buffering. Not fixed in Phase 6.

## Never gates (spot-check after change)

| Test | gem5 |
|------|------|
| MP+fence.rw.rws | Never |
| SB+fence.rw.rws | Never |
| AMO-FENCE | Never |
| MP+fence.w.w+addr-rfi | Never |
| MP+fence.w.w+fence.tso | Never |
| SB | Sometimes |
