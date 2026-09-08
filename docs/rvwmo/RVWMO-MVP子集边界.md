# gem5 RISC-V RVWMO MVP — 子集边界说明书

日期：2026-09-08  
分支：`rvwmo-mvp`（工作树 `/ssdhome/maoweiming/gem5`）  
流水线：[`litmus-work/`](/ssdhome/maoweiming/gem5/litmus-work/)

## 已实现

1. **fence pred/succ → R/W barrier flags**（`FenceConstructor`）；空/I/O → 全屏障。  
2. **Minor 保守**：任一 R/W barrier 当屏障处理（不变 nop）。  
3. **O3 commit**：仅 **WriteBarrier** 强制排空 SQ；Read-only barrier 不再为执行屏障而排空全部 store。  
4. **aq/rl**：`rl`→WriteBarrier micro-fence；`aq`→ReadBarrier micro-fence。  
5. **fence.tso**：识别 `fm=8,pred=rw,succ=rw`；反汇编 `fence.tso`；语义按全屏障（手册允许）。  
6. **litmus 流水线**：Docker 交叉编译 + `gem5-build` SE O3 门禁脚本。

## 故意过强（债务）

- Classic 缓存下 MP/LB 弱结果常打不出（记为过强，非 Forbidden 泄露）。  
- WriteBarrier 仍整队排空 SQ。  
- fence.tso ≡ fence rw,rw（合法过强）。  
- I/O / 空 fence = 全屏障。  
- Minor 对部分 fence 仍当全屏障。

## 未做（非 MVP）

- Ruby/CHI 消费 `Request::ACQUIRE/RELEASE`  
- Ztso / `needsTSO` 切换  
- 全量 litmus-tests-riscv  
- LKMM / klitmus7  
- 完整 MCA / IRIW 协议级保真  

## 硬门禁（合入标准）

herd **Never** ⇒ gem5 O3 **Never**。见 `litmus-work/mvp-signoff/`。

## 原则

**never weaker than RVWMO**
