# Phase 1 Minor conservative policy

Minor previously only honored `isFullMemBarrier()` (both R and W flags).
After Phase 1 partial fence flags, that would turn `fence w,w` into an ordering nop on Minor.

Change: Minor LSQ/Execute treat `isReadBarrier() || isWriteBarrier()` as a memory barrier.
Effect: partial fences remain **over-strong** on Minor, never weaker.
