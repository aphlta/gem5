# Sometimes KPI 清单（Phase C 锁定，Reduce 目标）

日期基线：以 `expected/debt-scoreboard.md` 最新一次再生为准。  
硬门禁不变：herd **Never** ⇒ gem5 **Never**。

## 本轮必须打成 gem5 Sometimes 的优先项

| # | Litmus | 说明 |
|---|--------|------|
| 1 | `BASIC_2_THREAD/MP.litmus` | R0 过强债务；Classic O3 主 KPI |
| 2 | `BASIC_2_THREAD/LB.litmus` | R0 过强债务；与 MP 并列 |
| 3 | `harness/MP-fence-w-w.litmus` | 本地 fence.w.w；**仅当 herd=Sometimes** 时计入 KPI |

验收（Reduce，非本 Phase）：上表 **≥1（力争 2）** 条从 `over-strength debt` 变为 gem5 **Sometimes**，且既有 Never 门禁不破。

## Backlog（不阻塞 A/B）

计分板中其余 `over-strength debt` 记入 backlog，本轮不强制清零。

## 相关命令

```bash
cd /ssdhome/maoweiming/gem5/litmus-work
./scripts/run_debt_scoreboard.sh -s 50 -r 1   # 再生债务表
./scripts/run_r2_suite.sh -s 50 -r 1 --max 60 # R2 抽样（Never 泄露即 fail）
```
