# Phase 1 fence flag expectations

## Before (baseline assertion)

Decoder hardcoded `IsReadBarrier | IsWriteBarrier` for every data `fence`, so:

| Encoding | Flags (old) |
|----------|-------------|
| `fence w,w` | Read+Write (full) |
| `fence r,r` | Read+Write (full) |
| `fence rw,rw` | Read+Write (full) |

`fence w,w` and `fence rw,rw` were **indistinguishable** at the flag layer.

## After (Phase 1)

`FenceConstructor` maps pred/succ R/W bits:

| Encoding | Flags (new) |
|----------|-------------|
| `fence w,w` | Write only |
| `fence r,r` | Read only |
| `fence rw,rw` | Read+Write |
| empty / any I/O | Read+Write (over-strong) |

Minor treats any R/W barrier as a barrier (never nop). O3 commit drain policy unchanged (still may over-strengthen).

**Not complete RVWMO yet.**
