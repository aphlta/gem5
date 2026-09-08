# Phase 3 aq/rl + Request flags

## MemFenceMicro mapping (implemented)

| Bit | Micro-fence flags |
|-----|-------------------|
| `rl` only | `IsWriteBarrier` |
| `aq` only | `IsReadBarrier` |
| `aq`+`rl` | both microops (write then atomic then read) |

## `Request::ACQUIRE` / `RELEASE`

**Not wired in MVP.** Classic O3+caches acceptance does not require protocol-level ACQ/REL.
CHI/Ruby consumption is deferred (post-MVP). Avoid half-hooked Request flags without tests.
