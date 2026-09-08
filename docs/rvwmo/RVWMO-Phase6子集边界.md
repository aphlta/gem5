# gem5 RISC-V RVWMO — Phase 6 子集边界

日期：2026-09-08  
分支：`rvwmo-mvp`  
流水线：[`litmus-work/`](../../litmus-work/)

## 相对 MVP 新增

1. **债务计分板**：`./scripts/run_debt_scoreboard.sh` → `expected/debt-scoreboard.md`（herd | gem5 | ok/过强债务/回归失败）。  
2. **R2 半自动套件**：`./scripts/run_r2_suite.sh -n N -s SIZE -r RUNS`；Never 泄露即 fail。  
3. **Classic O3 PodWW 窗口**（`lsq_unit.cc`）：`!needsTSO` 时短暂延迟 oldest store WB，并允许不同地址 canWB store 乱序写回 → **MP Sometimes**。  
4. **Ztso**：扩展可启用；`RiscvO3CPU.syncNeedsTSOFromZtso()` 绑定 `needsTSO`；双模式表 `expected/ztso-vs-rvwmo.md`（`ZTSO=1`）。  
5. **aq/rl → Request::ACQUIRE/RELEASE**（`amo.isa`）；修复 `Request::isAcquire()` 读 Flags。  
6. **CHI 冒烟脚本**：`USE_RUBY=1 RUBY_PROTOCOL=CHI` + ALL 二进制（见 `expected/chi-smoke.md`）。

## Sometimes KPI（本轮）

| Test | 目标 | 结果 |
|------|------|------|
| `MP.litmus` | Sometimes | **Sometimes**（例：194/600 @ `-s 200 -r 3`） |
| `LB.litmus` | Sometimes（力争） | **Never**（结构性：in-order ROB commit，记债务） |
| `SB.litmus` | Sometimes（保持） | Sometimes |

## 故意过强（剩余债务）

- **LB**：in-order commit 下无法做真正的 load-buffering。  
- WriteBarrier 仍整队排空 SQ。  
- fence.tso ≡ fence rw,rw；I/O / 空 fence = 全屏障。  
- Classic MCA / IRIW 弱结果仍难；CHI 路径若仍过强，记债务不强制改弱协议。  
- Minor 对部分 fence 仍当全屏障。

## 硬门禁

herd **Never** ⇒ gem5 O3 **Never**。`./scripts/run_mvp_signoff.sh` 须全绿。

## 原则

**never weaker than RVWMO** — Forbidden 泄露立即回滚。
