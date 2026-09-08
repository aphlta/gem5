# gem5 实现 RISC-V RVWMO 完整计划

日期：2026-09-08  
最终目标：**在 gem5 上实现可用的 RVWMO 保真（至少 O3 + Classic caches），并用 litmus（对照 herd `riscv.cat`）验收。**  
原则：**never weaker than RVWMO**（规范 Forbidden 的结果在 gem5 上必须 Never；Allowed 的弱结果在 O3 上应能 Sometimes，否则仍算「假强」未完成）。

相关已有笔记：

- [RVWMO-litmus-herd入门笔记.md](./RVWMO-litmus-herd入门笔记.md)
- 工作目录：`/ssdhome/maoweiming/gem5/litmus-work/`
- 工具：`xiangshan/.opam-root` 的 herd7/litmus7；Docker `xs-env` 交叉编译；容器 `gem5-build` 跑仿真
- 测试源：`xiangshan/litmus-tests-riscv`

---

## 0. 成功定义（Done）

### 0.1 必须达成（MVP / 可演示 RVWMO）

1. **解码正确**：`fence pred,succ` 按 R/W（及文档约定的 I/O）置 barrier flags；`fence.tso` 可识别；aq/rl 不再一律双全屏障。  
2. **O3 执行按部分屏障区分**：`fence.w.w` 与 `fence.rw.rw` 在 litmus/微基准上行为可区分。  
3. **安全底线**：凡 herd 判 **Forbidden/Never** 的结局，gem5 O3+caches 上 **不得出现**（统计意义下的 Never）。  
4. **弱序能力**：无屏障 SB（及选定的 Allowed 用例）在 O3 上保持/恢复 **Sometimes**（证明不是假强到「什么弱序都没有」）。  
5. **可复现流水线**：一键或脚本化 `litmus7 → 交叉编译 → gem5 SE → 对照 herd`。  
6. **文档**：说明「实现了哪一子集、故意过强在哪里、未做 CHI/Ztso」。

### 0.2 明确不纳入 MVP（后续里程碑）

| 项 | 原因 |
|----|------|
| Ruby/CHI 完整消费 ACQUIRE/RELEASE | 协议工程量大，可作 Phase E |
| 全量 litmus-tests-riscv 上千条 | 用分级回归集即可 |
| Ztso 可切换流水线 | 独立产品特性 |
| I/O fence 与设备模型全对齐 | 可过强保留 |
| Minor/Atomic 也变成「真弱」 | Atomic 作强对照即可；Minor 以「不弱于」为底线 |
| LKMM / klitmus7 | 另一条规范线 |

### 0.3 判读标准（每条 litmus）

| herd（`riscv.cat`） | gem5 O3 期望 |
|---------------------|--------------|
| Observation **Never** | **Never**（硬门禁） |
| Observation **Sometimes** | 优先 **Sometimes**；短期可为 Never（记「仍过强」债务） |
| 实现改动后新出现 herd-Never 结果 | **阻断合入** |

---

## 1. 总体架构（改什么）

```text
                    ┌─ decoder：PRED/SUCC、fm、aq/rl → flags / microops
指令 ──► RISC-V ISA ┤─ MemFenceMicro / Request ACQ/REL（可选）
                    └─ 反汇编与测试钩子
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
     O3 MemDepUnit / LSQ / Commit    Minor（保守：非 full 勿变 nop）
     （部分屏障真执行；commit 慎改）
                           │
                           ▼
              Classic caches（MVP 主战场）
              （Phase E 再接 Ruby/CHI）
                           │
                           ▼
              litmus7 harness + herd oracle
```

---

## 2. 阶段总览

| 阶段 | 名称 | 目标 | 预估 |
|------|------|------|------|
| **P0** | 基线与工程化 | 摸底表 + 可复跑脚本 + 分支策略 | 3–5 天 |
| **P1** | 可观测对齐（W1） | decoder flags；执行仍可过强 | 3–5 天 |
| **P2** | O3 部分屏障（W2） | w.w vs rw.rw 可区分；Never 门禁绿 | 1–2 周 |
| **P3** | aq/rl（W3） | 原子指令屏障语义对齐子集 | 1 周 |
| **P4** | fence.tso / 空 fence（W4） | 编码与语义入回归 | 3–5 天 |
| **P5** | 扩展回归与文档（MVP 冻结） | 分级 litmus 集 + 说明「子集边界」 | 3–5 天 |
| **P6** | （可选）协议 / Ztso | CHI ACQ/REL、Ztso | 研究级另开 |

**MVP 完工点 = P0–P5 完成。**  
合计粗估 **5–8 周**（单人兼职按日历拉长；全职可压缩）。

工作树建议：`/ssdhome/maoweiming/gem5` 开分支 `rvwmo-mvp`（或 `gem5-develop` 同步策略另定）；仿真始终在 `gem5-build` 容器。

---

## 3. Phase 0 — 基线与工程化

### 3.1 任务

1. 固化 Docker 流水线脚本（生成 / 编译 / 跑 / 解析 Observation）。  
2. 建立 **基线结果表**（改代码前）：同一二进制，Atomic vs O3。  
3. 选定 **回归集 R0 / R1 / R2**（见 §6）。  
4. herd 金标准批量跑 R0，写入 `expected/`。

### 3.2 基线必跑（已部分完成）

| 测试 | herd | gem5 Atomic（预期） | gem5 O3（摸底） |
|------|------|---------------------|-----------------|
| `BASIC_2_THREAD/SB` | Sometimes | Never | Sometimes（已测 27/50） |
| `BASIC_2_THREAD/MP` | Sometimes | Never | TBD |
| `BASIC_2_THREAD/LB` | Sometimes | Never | TBD |
| `BASIC_2_THREAD/MP+fence.rw.rws` | Never | Never | Never |
| `HAND/MP+fence.w.w+…`（选 1 条简单） | 视具体 | TBD | TBD |

### 3.3 验收

- [ ] 脚本：`run_litmus_gem5.sh <litmus> <cpu>` 可复现  
- [ ] 基线表落入 PDOCS 或 `litmus-work/baseline.md`  
- [ ] `-n` 规则文档化（2 线程 ≥4；4 线程 IRIW ≥8）

---

## 4. Phase 1 — Decoder 可观测对齐（不改弱）

### 4.1 代码触点

- `src/arch/riscv/isa/decoder.isa`（fence）  
- `src/arch/riscv/isa/bitfields.isa`（PRED/SUCC）  
- `src/arch/riscv/isa/formats/standard.isa`（反汇编）  
- 单测：flag / disassembly gtest（若仓库已有 ISA 测试框架则接入）

### 4.2 行为

- 按 pred/succ 的 R/W 位置 `IsReadBarrier` / `IsWriteBarrier`。  
- **Commit 排空策略暂不改** → 整体仍可过强。  
- Minor：若只有单边 flag，保持「当 full」或显式保守，**禁止变成 nop**。

### 4.3 验收

- [ ] 反汇编与 flags 一致  
- [ ] R0 上 **无新的 Forbidden 结果**  
- [ ] SB O3 仍 Sometimes（不误伤）  
- [ ] PR/笔记写明：**不是完整 RVWMO**

---

## 5. Phase 2 — O3 部分屏障真执行（核心）

### 5.1 代码触点

- `src/cpu/o3/mem_dep_unit.*`（已具备 R/W 区分能力，需确认 RISC-V 输入）  
- `src/cpu/o3/commit.*`（屏障时是否一律 drain SB — **高风险改点**）  
- `src/cpu/o3/lsq*`（与 release/acquire、写回可见性相关则谨慎动）

### 5.2 设计约束

1. 任何改弱路径必须先有 **对应 litmus 红绿门禁**。  
2. 读屏障 / 写屏障对称性按 RVWMO PPO + fence 语义文档化。  
3. 默认策略：宁可短暂「仍过强」，不可「偶发弱于 herd」。

### 5.3 验收（硬）

- [ ] `MP+fence.rw.rws`（或等价）：gem5 **Never**  
- [ ] 无 fence `MP`：O3 **Sometimes**（或记录债务）  
- [ ] 选定 `MP+fence.w.w`：与 `rw.rw` **可区分**（结果集或性能/内部计数至少一种可区分；优先结果集）  
- [ ] R1 全部门禁：零 Forbidden 泄露  

### 5.4 回滚条件

一旦出现 herd-Never 结果在 O3 上 Sometimes → **立即回滚 commit/LSQ 改动**，只保留 decoder。

---

## 6. Phase 3 — aq / rl

### 6.1 代码触点

- `src/arch/riscv/isa/formats/amo.isa`  
- `src/arch/riscv/insts/amo.*`（MemFenceMicro）  
- 可选：`Request::ACQUIRE/RELEASE` 挂到 packet（为 Phase 6 铺路；MVP 可不接 CHI）

### 6.2 验收

- [ ] 选 `RelAcq_2_THREAD` 或 `HAND` 中带 aq/rl 的 2–4 条  
- [ ] herd Never → gem5 Never  
- [ ] 不再对「仅 aq」或「仅 rl」无条件插双全屏障（语义与文档一致）

---

## 7. Phase 4 — fence.tso / 空 fence

### 7.1 代码触点

- decoder 增加 `fm` / `fence.tso` 路径  
- 空 pred/succ 的定义与手册对齐（可文档化为「实现过强」若暂不细分）

### 7.2 验收

- [ ] `HAND/MP+fence.w.w+fence.tso.litmus` 等 1–2 条入 R1  
- [ ] 反汇编可见 `fence.tso`  
- [ ] Never 门禁不破

---

## 8. Phase 5 — MVP 冻结

### 8.1 交付物

1. 代码分支 + 简短设计说明（子集边界）。  
2. 回归脚本 + R0/R1 期望表。  
3. PDOCS 更新：「已实现 / 故意过强 / 未做」。  
4. （可选）上游 enhancement issue / RFC 草稿。

### 8.2 MVP 签字标准

- R1 全部 Never 门禁通过；R0 弱序能力（SB）不退化。  
- 书面列出剩余过强点（例如 I/O、CHI、部分 PPO）。

---

## 9. Phase 6 — 可选扩展（非 MVP）

| 工作 | 内容 |
|------|------|
| E1 | Ruby/CHI：AMO/fence → ACQUIRE/RELEASE；IRIW 类对照 |
| E2 | Ztso + `needsTSO` 可切换 |
| E3 | 全量/半自动 litmus-tests-riscv 夜跑 |
| E4 | FS 模式 + 亲和性，贴近真机 litmus7 |

---

## 10. Litmus 分级回归集

### R0 — 冒烟（每次提交前，分钟级）

- `BASIC_2_THREAD/SB.litmus`  
- `BASIC_2_THREAD/MP.litmus`  
- `BASIC_2_THREAD/LB.litmus`  
- `BASIC_2_THREAD/MP+fence.rw.rws.litmus`  

规模建议：开发时 `-s 50 -r 1`；门禁时 `-s 200 -r 5`（按时间调）。

### R1 — MVP 门禁（合入前）

在 R0 上增加：

- `BASIC_2_THREAD/MP+fence.rw.rw+po.litmus`（或套件中最简强 fence MP）  
- `HAND/MP+fence.w.w+addr-rfi.litmus`（或更简的纯 `MP+fence.w.w` 若另生成）  
- `HAND/SB+fence.rw.rw+ctrlfence.r.r.litmus`（或 `SB+…rw.rw…`）  
- aq/rl：从 `RelAcq_2_THREAD/` 选 2 条  
- `fence.tso`：`HAND/MP+fence.w.w+fence.tso.litmus`  

### R2 — 扩展（周更）

- `SAFE/IRIW+fence.rw.rws.litmus` 等（`-n` 加大）  
- `AMO_X0_2_THREAD/` 抽样  
- `FENCE.TSO/` 目录抽样  

每条记录：`herd` 结果、`gem5-O3` 结果、差异分类（ok / 过强债务 / **回归失败**）。

---

## 11. 工程与环境约定

| 项 | 约定 |
|----|------|
| 仿真容器 | `docker exec gem5-build …` |
| 交叉编译 | `ghcr.io/openxiangshan/xs-env` + `riscv64-linux-gnu-gcc -static` |
| 配置脚本 | `configs/deprecated/example/se.py`（直到迁移到 gem5_library） |
| CPU | 验收：**DerivO3CPU --caches**；Atomic 仅对照 |
| 核数 | 2 线程 litmus：`-n 4`；4 线程：`-n 8+` |
| harness cfg | `affinity=none`，`barrier=userfence`（已验证可跑） |
| 主机 | 勿直接跑 `gem5.opt`（glibc 过旧） |

---

## 12. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 改 commit 排空导致弱于 RVWMO / 搞挂 Linux | 门禁 litmus 先行；小步 PR；可回滚 |
| SE pthread / futex hang（历史 #1320） | 固定 userfence；控制 `-n`；必要时改 baremetal harness |
| Classic 解释不了 IRIW/MCA | MVP 不承诺；标到 Phase 6 |
| O3 太慢 | R0 小规模；夜跑 R1/R2 |
| Minor 与 O3 语义分叉 | Minor 保守过强；文档写明 |
| 「Sometimes 打不出」被误认为完成 | Done 标准同时要求弱序能力 + Never 门禁 |

---

## 13. 里程碑检查清单（给自己用）

- [ ] **M0** 基线表 + 脚本  
- [ ] **M1** Decoder PR（过强允许）  
- [ ] **M2** O3 部分屏障 + R1 Never 全绿 + SB Sometimes  
- [ ] **M3** aq/rl 子集  
- [ ] **M4** fence.tso  
- [ ] **M5** MVP 文档冻结 / 可选上游 RFC  

---

## 14. 建议执行顺序（下周起）

1. **本周**：P0 — 脚本化 + 补全 MP/LB/强 fence 基线表（不改微架构）。  
2. **其后**：P1 decoder。  
3. **再后**：P2（每次改动只对准一条 litmus 差分）。  
4. P3→P4→P5 收束 MVP。  

**禁止**：跳过 P0/P1，直接改 O3 commit「为了弱」。

---

## 15. 一句话目标陈述（可写进分支描述）

> 在 gem5 O3 + Classic 上交付 RISC-V RVWMO **可演示子集**：fence/aq·rl 语义可区分，litmus 相对 herd **永不弱于规范**，并保留无屏障弱序观测能力；CHI/Ztso/全量套件列为后续。
