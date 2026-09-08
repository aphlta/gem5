# Phase 2 O3 partial-fence design (P2.2)

## Problem

Before Phase 2, `Commit::commitHead` waits for **all** stores to write back whenever the ROB head is any read **or** write barrier. Combined with Phase-1 flags, `fence r,r` still forced a full store-buffer drain — stronger than needed and erases R/W distinctions.

## Policy (never weaker than RVWMO)

| Barrier flags on ROB head | Drain SQ before executing barrier? | Rationale |
|---------------------------|--------------------------------------|-----------|
| WriteBarrier (incl. full) | **Yes** | Prior writes must be ordered before later memory ops that the write-side of a fence constrains. |
| ReadBarrier only | **No** (Phase 2) | Acquire-like / read-side fence should not need to flush prior stores to become a read barrier; MemDep still tracks load vs store barrier SNs. |
| Non-barrier | n/a | unchanged |

`inst_num > 0` still blocks (commit younger ops first) — unchanged.

## Explicitly still over-strong (debt)

- Classic cache MCA / IRIW not modeled as full RVWMO.
- Write-barrier still drains entire SQ (not byte-precise pred set).
- I/O / empty fences remain full barriers from Phase 1.
- Minor still treats any R/W barrier as full-strength.

## Rollback

If any R1 herd-**Never** litmus becomes gem5 **Sometimes**, revert the commit.cc change immediately.
