# Phase 6 Reduce — Classic O3 减过强设计（R.1）

日期：2026-09-08  
对照：[`p2-o3-fence-design.md`](p2-o3-fence-design.md)

## 现象

| Litmus | herd | gem5 O3（MVP） | 根因摘要 |
|--------|------|----------------|----------|
| SB | Sometimes | Sometimes | 本地 store buffer：load 可在对方 store 全局可见前读到旧值 |
| MP | Sometimes | Never | SQ **按程序序写回** + Classic MCA ⇒ `Wy` 可见则 `Wx` 必已可见 |
| LB | Sometimes | Never | **ROB 按序提交**：older load 必须先执行/提交，younger store 才能 WB；双核对称下存在可见性循环，结构性打不出 |

## 允许的下一步窗口（本轮）

1. **仅当 `needsTSO=False`（默认 RVWMO）** 时，允许 **不同地址（字节不重叠）** 的已提交 store **乱序写回**（PodWW 窗口），以打出 MP Sometimes。  
2. **同地址（字节重叠）** 的 store 仍保持程序序写回。同 cache line、不同地址**允许**重排——litmus 常用 `stride=1`，若按线锁死则 MP 窗口被结构性抹掉，且 RVWMO 本身允许同线异址 PodWW。  
3. **Hold 窗口**：最老 store 变 `canWB` 后若 SQ 中仍有更年轻未提交 store，延迟最多 ~32 cycle 再发送，否则最老会在同拍写回、永远看不到“双 ready”。  
4. **`Request::RELEASE` / LLSC** 仍必须在 SQ 队头写回（既有 LSQ 约束，never weaker）。  
5. **WriteBarrier（fence 含 W）** 仍在 commit 时 **整队排空 SQ**（P2 策略不变）。本轮**不**削弱 WriteBarrier drain。  
6. **`needsTSO=True`（Ztso）** 保持 FIFO store 写回 + 既有 TSO squash 路径。

## 禁止碰的路径

- 不改 ROB 按序提交（不开放 LB 所需的 “load buffering 过 store” 硬件幻觉）。  
- 不削弱 WriteBarrier 排空。  
- 不让 herd-Never 的 fence/AMO 门禁出现 Forbidden 泄露。  
- 不在无 fence 的路径上引入弱于 RVWMO 的同地址重排。  
- 不实现 Ztso / ACQ·REL / CHI（留给 Phase B/A）。

## 最小刀口

- 文件：`src/cpu/o3/lsq_unit.cc` / `.hh` — `selectStoreForWriteback()` + `writebackStores()` / `storePostSend()`  
- 行为：`!needsTSO` 时（1）对“SQ 内仍有更年轻未 `canWB`”的最老 store 短暂 hold；（2）在可写回集合中优先选择 **更年轻、与更老未发送 store 字节不重叠** 的条目发送；发送非队头时不推进 `storeWBIt`，随后跳过已 `committed()` 的洞。  
- 新增 `storeSendIt` / `storeWBHoldCycles`。

## LB 处置

LB 记为 **结构性过强债务**（in-order commit），本轮 KPI 以 **MP Sometimes** 为主；LB 若偶然打出则记分板更新，不强制。

## 回滚

任一 R1/signoff herd-**Never** 变为 gem5 **Sometimes/Always** ⇒ 立即回滚本改动。
