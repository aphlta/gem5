# RVWMO / litmus / herd 入门笔记（阶段 A）

日期：2026-09-08（同日补：gem5 SE 跑通 SB）  
范围：规范与工具方法论；gem5 侧已用 litmus7 harness 冒烟。  
下一步（阶段 B）：gem5 RVWMO 保真 / 部分屏障。

---

## 1. 名词对照

| 名称 | 含义 |
|------|------|
| **RVWMO** | RISC-V Weak Memory Ordering，ISA 默认弱内存模型（常被口误写成 RVMMO） |
| **litmus 测试** | 极短多线程程序 + `exists (...)`，用来观察/穷举并发结果 |
| **herd7** | 给定 `.cat` 模型，穷举 litmus 在规范下的允许结果 |
| **litmus7** | 在真机/系统上跑用户态 litmus，统计实际观测 |
| **diy7** | 从简短规格批量生成 `.litmus` |
| **klitmus7** | 把 litmus 转成**内核模块**跑（主攻 LKMM，不是 ISA RVWMO 第一工具） |

三层分工：

```text
规范（RVWMO） → herd7 + riscv.cat（允许集合）
生成          → diy7
真机观察      → litmus7
微架构实验    → gem5（阶段 B）
```

---

## 2. 本机工具路径（已跑通）

未重新编译源码树；直接使用已有 opam 安装：

```bash
export PATH="/ssdhome/maoweiming/xiangshan/.opam-root/default/bin:$PATH"
export OPAMROOT="/ssdhome/maoweiming/xiangshan/.opam-root"

herd7 -version    # 7.58
litmus7 -version  # 7.58
```

相关目录：

| 用途 | 路径 |
|------|------|
| herdtools7 源码 | `/ssdhome/maoweiming/xiangshan/herdtools7` |
| RISC-V litmus 套件 | `/ssdhome/maoweiming/xiangshan/litmus-tests-riscv` |
| RVWMO 公理模型 | `.../herdtools7/herd/libdir/riscv.cat` |
| 基础双线程测试 | `.../litmus-tests-riscv/tests/non-mixed-size/BASIC_2_THREAD/` |

复跑命令：

```bash
BASE=/ssdhome/maoweiming/xiangshan/litmus-tests-riscv/tests/non-mixed-size/BASIC_2_THREAD
CAT=/ssdhome/maoweiming/xiangshan/herdtools7/herd/libdir/riscv.cat

herd7 -model "$CAT" "$BASE/SB.litmus"
herd7 -model "$CAT" "$BASE/MP.litmus"
herd7 -model "$CAT" "$BASE/LB.litmus"
```

说明：

- 本日 **未** 跑 litmus7 真机（需多核 RISC-V）；阶段 A 以 herd 金标准即可验收。
- 源码树 `xiangshan/herdtools7` 若以后要自己改工具再 `make`；当前不必重编。

---

## 3. 三个经典测试（本次 herd 结果）

均来自 `BASIC_2_THREAD`，模型 `riscv.cat`。  
共同模式：`Test … Allowed`，目标结果 `Observation … Sometimes`（规范**允许**该弱结果出现）。

### 3.1 SB（Store Buffering）

```text
P0:  sw 1→x ; lw y→r0
P1:  sw 1→y ; lw x→r1
exists (r0=0 /\ r1=0)
```

- **在测什么**：两边都先写后读另一地址，能否都读到旧值 0。
- **弱序来源直觉**：本地 store buffer / 写未全局可见时就发后续 load。
- **本次 herd**：Allowed；`exists` 有 Positive witness → **Sometimes**。

### 3.2 MP（Message Passing）

```text
P0:  sw 1→x ; sw 1→y          # 先数据后 flag
P1:  lw y→r0 ; lw x→r1         # 先看 flag 再读数据
exists (r0=1 /\ r1=0)
```

- **在测什么**：读到 flag=1 却读到数据旧值 0（消息传递失败形态）。
- **为何要 fence**：无屏障时 RVWMO **允许**；加合适 fence/aq·rl 可禁止。
- **本次 herd**：Allowed；Sometimes。

### 3.3 LB（Load Buffering）

```text
P0:  lw x→r0 ; sw 1→y
P1:  lw y→r1 ; sw 1→x
exists (r0=1 /\ r1=1)
```

- **在测什么**：两边都先 load 后 store，能否形成“互相读到对方新写”的环。
- **本次 herd**：Allowed；Sometimes。

### 3.4 读 herd 输出的关键行

| 字段 | 含义 |
|------|------|
| `States N` | 穷举到的最终状态数 |
| `Condition exists (...)` | litmus 关心的目标结果 |
| `Positive / Negative` | 满足 / 不满足 exists 的执行数（在模型探索下） |
| `Observation … Sometimes` | 目标结果**有时**出现（Allowed 且 Positive>0） |
| `Never` | 模型下目标结果不出现（常用作“屏障是否够强”的期望） |
| `Always` | 每次都满足 exists（少见） |

验收口诀（阶段 B 也会用）：

1. herd 说 **Never** 的结果，实现里**绝不能**打出（never weaker than RVWMO）。  
2. herd 说 **Sometimes** 的结果，偏强实现可以暂时打不出；保真研究再追求能打出。

---

## 4. 和 gem5 / NEMU 的关系（备忘）

| 平台 | 与 RVWMO |
|------|----------|
| **herd7** | 规范允许集合的金标准 |
| **NEMU** | 功能解释器，`fence` 近空操作，**不实现弱序**；作 difftest 金模合适 |
| **gem5（现状）** | RISC-V `fence`/aq·rl 常落成全屏障 → **合法但偏强**；适合做阶段 B 保真 |

阶段 B 入口（尚未动手）：

- `src/arch/riscv/isa/decoder.isa`（fence）
- `src/arch/riscv/isa/formats/amo.isa`（aq/rl → MemFenceMicro）
- O3 LSQ / MemDepUnit

---

## 5. 在 gem5 里跑 litmus（路径 A，已冒烟）

gem5 **不能直接吃** `.litmus`。流程：

```text
.litmus → litmus7 -cross 生成 C harness
       → Docker(xs-env) 里 riscv64-linux-gnu-gcc 静态编译
       → Docker(gem5-build) 里用 gem5.opt SE 多核跑 run.exe
       → 对照 herd 的 Allowed / Never
```

### 5.1 本机产物目录

`/ssdhome/maoweiming/gem5/litmus-work/`

| 内容 | 路径 |
|------|------|
| gem5 友好 cfg（关 affinity、小规模） | `riscv-gem5.cfg` |
| 生成的 SB harness | `sb-gem5/` |
| Atomic `-n 4` 日志 | `gem5-sb-atomic-n4.log` |
| O3 + caches `-n 4` 日志 | `gem5-sb-o3.log` |

### 5.2 复跑命令摘要

```bash
# 1) 主机：生成（已有 litmus7）
export PATH="/ssdhome/maoweiming/xiangshan/.opam-root/default/bin:$PATH"
OUT=/ssdhome/maoweiming/gem5/litmus-work
# 使用 OUT/riscv-gem5.cfg；litmus7 -cross ...

# 2) Docker：交叉编译
docker run --rm -v "$OUT:/work" -w /work/sb-gem5/src \
  ghcr.io/openxiangshan/xs-env:latest \
  bash -lc 'make GCC=riscv64-linux-gnu-gcc'

# 3) Docker：跑 gem5（容器 gem5-build 已挂载本仓库 → /gem5）
# 注意：se.py 在 configs/deprecated/example/se.py
# 2 线程 litmus 至少要 -n 4（主线程 + P0/P1，-n 2 会 pthread_create 失败）
docker exec gem5-build bash -lc '
  cd /gem5
  ./build/RISCV/gem5.opt --outdir=/gem5/litmus-work/m5out-sb-o3 \
    configs/deprecated/example/se.py \
    -n 4 --cpu-type=DerivO3CPU --caches \
    -c /gem5/litmus-work/sb-gem5/src/run.exe --mem-size=256MB
'
```

主机直接跑 `build/RISCV/gem5.opt` 会因 **glibc/libpython** 过旧失败；仿真请进 `gem5-build`（ubuntu 22.04）。

### 5.3 本次 SB 实测（`-s 50 -r 1`）

| 配置 | Observation | 含义 |
|------|-------------|------|
| herd + `riscv.cat` | **Sometimes** | 规范允许两边都读到 0 |
| gem5 SE Atomic `-n 4` | **Never**（0/50） | 顺序执行，打不出 SB 弱结果 |
| gem5 SE **O3+caches** `-n 4` | **Sometimes**（27/50） | store buffer 等机制打出了弱结果 |

说明：

- **无 fence 的 SB** 在当前 O3 上已经能弱；这与「fence 一律全屏障」不是同一缺口。  
- fence / aq·rl 相关 litmus 才是阶段 B 保真的主战场。  
- SE 多核仍可能踩 pthread/futex 坑；本次 `barrier=userfence` + 关 affinity 可跑通。

---

## 6. 本日验收

- [x] 能调用本机 `herd7` 7.58  
- [x] SB / MP / LB 在 `riscv.cat` 下跑通，三者目标结果均为 **Sometimes**  
- [x] 短笔记落盘（本文件）  
- [x] litmus7→Docker 交叉编译→gem5 SE 跑通 **SB**（Atomic Never / O3 Sometimes）  
- [ ] litmus7 真机对照（有多核 RISC-V 后再做）  
- [ ] gem5 上再跑 MP / LB（同流程）

---

## 7. 参考链接

- herdtools7：<https://github.com/herd/herdtools7>  
- litmus-tests-riscv：<https://github.com/litmus-tests/litmus-tests-riscv>  
- diy 教程：<https://diy.inria.fr/doc/diy.pdf>  
- RISC-V RVWMO（手册 Unpriv 章）  
- LKMM / klitmus7（内核线，后续可选）：<https://docs.kernel.org/dev-tools/lkmm/readme.html>
