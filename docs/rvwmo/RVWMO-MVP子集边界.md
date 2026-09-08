# RVWMO MVP — 子集边界说明书

日期：2026-09-08（Phase 6 更新）  
分支：`rvwmo-mvp`（工作树 `/ssdhome/maoweiming/gem5`）  
流水线：[`litmus-work/`](/ssdhome/maoweiming/gem5/litmus-work/)  
详见：[`RVWMO-Phase6子集边界.md`](RVWMO-Phase6子集边界.md)

## 已实现

1. **fence pred/succ → R/W barrier flags**（`FenceConstructor`）；空/I/O → 全屏障。  
2. **Minor 保守**：任一 R/W barrier 当屏障处理（不变 nop）。  
3. **O3 commit**：仅 **WriteBarrier** 强制排空 SQ；Read-only barrier 不再为执行屏障而排空全部 store。  
4. **aq/rl**：`rl`→WriteBarrier micro-fence；`aq`→ReadBarrier micro-fence；**Request ACQUIRE/RELEASE** 已挂到 LR/SC/AMO。  
5. **fence.tso**：识别 `fm=8,pred=rw,succ=rw`；语义按全屏障（手册允许）。  
6. **litmus 流水线**：Docker 交叉编译 + `gem5-build` SE O3；债务计分板 / R2 / signoff。  
7. **Phase 6 Reduce**：`!needsTSO` 下不同地址 store 可乱序写回（短暂 hold）→ **MP Sometimes**。  
8. **Ztso**：可启用并绑定 O3 `needsTSO`。

## 故意过强（债务）

- **LB** 仍常为 Never（in-order commit 结构性债务）。  
- WriteBarrier 仍整队排空 SQ。  
- fence.tso ≡ fence rw,rw（合法过强）。  
- I/O / 空 fence = 全屏障。  
- Minor 对部分 fence 仍当全屏障。  
- Classic / CHI IRIW 弱结果可能仍过强。

## 未做（非本轮）

- LKMM / klitmus7  
- 宣称完整手册 RVWMO / MCA 已证明  
- 无条件把 WriteBarrier 改到弱于 herd  

## 硬门禁（合入标准）

herd **Never** ⇒ gem5 O3 **Never**。见 `litmus-work/mvp-signoff/`。

## 原则

**never weaker than RVWMO**
