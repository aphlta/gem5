# Phase 2 MemDep path confirmation (P2.3)

Source: `src/cpu/o3/mem_dep_unit.cc` `insertBarrierSN`:

- `isReadBarrier()` => insert into `loadBarrierSNs`
- `isWriteBarrier()` => insert into `storeBarrierSNs`
- Debug distinguishes "memory" / "read" / "write" barrier types

After Phase 1, `fence w,w` sets only WriteBarrier, so it enters **store** barrier set only.
`fence rw,rw` enters **both** sets.

No MemDep code change required for Phase 2 beyond commit drain policy.
