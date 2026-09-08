# Phase C：债务计分板与 R2（测量-only）

本页说明如何再生计分板与跑 R2；**不**包含 O3 Reduce / Ztso / ACQ·REL / CHI。

## 再生债务计分板

```bash
export PATH="/ssdhome/maoweiming/xiangshan/.opam-root/default/bin:$PATH"
cd /ssdhome/maoweiming/gem5/litmus-work

# 开发默认
./scripts/run_debt_scoreboard.sh -s 50 -r 1

# 合入前加大样本
./scripts/run_debt_scoreboard.sh -s 200 -r 5
```

输出：`expected/debt-scoreboard.md`  
种子：`scripts/debt_scoreboard.seed`（R0 + MP/LB/`MP+fence.w.w` + BASIC/SAFE/RELAX 可汇编抽样）  
跳过日志：`logs/debt-scoreboard-skips.log`

分类列：

| classification | 含义 |
|----------------|------|
| `ok` | 与 never-weaker 一致（含 herd Never→gem5 Never） |
| `over-strength debt` | herd Sometimes/Always，gem5 Never（Reduce 对象） |
| `regression fail` | Never 泄露或硬失败 |

## 跑 R2 半自动套件

```bash
# 先看会抽哪些（约 30–80，可用 --max 调整）
./scripts/run_r2_suite.sh --list-only --max 60

./scripts/run_r2_suite.sh -s 50 -r 1 --max 60

# 夜跑示例
./scripts/run_r2_suite.sh -s 200 -r 5 --max 80
```

报告：`r2-runs/latest.md`（时间戳副本同目录）  
**Never 泄露 ⇒ 脚本 exit 1**；build/不可汇编条目跳过并记 `logs/r2-suite-skips.log`。

## NUM_CPUS

脚本按 litmus 线程数自动设 `NUM_CPUS=2×#procs`（2 线程→4，IRIW→8）。否则 4 线程 IRIW 会在 SE 下 `pthread_create` 失败、无 Observation。

## Sometimes KPI

见 `expected/sometimes-kpi.md`（锁定 MP / LB / 本地 MP+fence.w.w）。
