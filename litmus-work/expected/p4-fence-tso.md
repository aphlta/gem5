# Phase 4 fence.tso / empty fence

## fence.tso

- Encoding: `fm=0x8`, `pred=RW`, `succ=RW` (`FM` bitfield `<31:28>`).
- Disassembly: prints `fence.tso`.
- Semantics in gem5 MVP: **full Read+Write barrier** (architecturally allowed; over-strong vs pure TSO fence that omits store→load).

## Empty fence (`pred=0,succ=0`, `fm=0`)

- Treated as **full barrier** (never weaker). Spec allows HINT-like null orderings; we choose over-strong for safety.

## I/O bits

- Any I/O in pred/succ => full barrier (Phase 1 policy retained).
