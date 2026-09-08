# aq/rl subset herd expectations

Assembler note: `RelAcq_2_THREAD` lw.aq/sw.rl forms do not assemble with
`riscv64-linux-gnu-as` in xs-env. MVP uses AMO `.aq`/`.rl` tests instead.

| Test | Observation |
|------|-------------|
| `HAND/AMO-FENCE.litmus` | **Never** (`~exists` both read 0) |

## Flag mapping (code)

| Bits | MemFenceMicro flags |
|------|---------------------|
| rl | WriteBarrier |
| aq | ReadBarrier |
| aq+rl | both micro-fences |

Request ACQUIRE/RELEASE: not wired (see `p3-aqrl-request-notes.md`).
