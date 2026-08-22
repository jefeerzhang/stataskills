---
name: stata-did-community-stacked
description: StackedDiD 堆叠 DID 参考：Wing, Hollingsworth & Freedman (2024) 堆叠估计量。Q 权重确保 cohort 聚合不混入负权重，D 统计量诊断 TWFE 偏误来源，DuckDB/Parquet 后端支持大数据。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-stacked

> **加载时机**：主 SKILL.md 决策树已读完，遇到"错时 DID + 想要设计诊断 D 统计量"或"大数据 100M+ 行"时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 6. StackedDiD：堆叠双重差分（Wing, Hollingsworth & Freedman 2024）

适用场景：**错时 DID 下担心 TWFE 负权重偏误**，且想要一个**透明可分解**的估计量——每个 adoption cohort 是一个独立子实验，Q 权重确保聚合时不混入负权重。与 `csdid`/`hdidregress` 的理论路径不同，StackedDiD 的核心优势是**设计诊断**：`stacked summary` 直接报告"未加权 TWFE 的隐含权重"与"目标 Q 权重"的差距（D 统计量），让你看到偏误来自哪里。

### 安装

```stata
* 尚未上 SSC，从 GitHub 安装
net install stacked, ///
    from("https://raw.githubusercontent.com/hollina/stacked/main/Stata") replace
* 获取示例数据（一次性）
net get stacked
```

依赖：`reghdfe`（可选，用于 `fe(interacted)` 和 `absorb()`）。无 `reghdfe` 时自动退化为 `regress`。

### 核心工作流（三步）

```stata
* 0. 加载示例数据
stacked use medicaid, clear

* 1. 筛选事件窗口（kappa 权衡表）
stacked kappa, time(year) unit(state) adopt(adopt_year) ///
    kpre(1/4) kpost(1/4)

* 2. 构建堆叠数据集
stacked build, time(year) unit(state) adopt(adopt_year) ///
    kpre(3) kpost(2)

* 3. Q 加权事件研究回归
stacked reg uninsured, cluster(state)

* 4. 出图
stacked plot
```

### 三步详解

**Step 1：`stacked kappa`** — 筛选事件窗口

不同 `(kpre, kpost)` 组合下的样本量权衡。`kpost` 太大 → 最新 cohort 被丢弃（没有足够的 post 期）。选一个所有 cohort 都能保留的组合。

```stata
stacked kappa, time(year) unit(state) adopt(adopt_year) ///
    kpre(1/4) kpost(1/4) screen
```

`screen` 选项额外输出 D 统计量（设计诊断）：D = Σ|w_a^S - w_a^T|，即未加权 TWFE 隐含权重与目标 Q 权重的总偏差。D ≈ 0 → 两种估计差异小；D 大 → 未加权 TWFE 可能严重偏误。

**Step 2：`stacked build`** — 构建堆叠数据集

将原始面板替换为堆叠数据集：每个 adoption cohort 一个子实验（`sub_exp`），含 `event_time`、`treat`、`post`、`q_weight` 变量。

```stata
stacked build, time(year) unit(state) adopt(adopt_year) ///
    kpre(3) kpost(2) controltype(both)
```

| 选项 | 含义 | 默认 |
|---|---|---|
| `time(varname)` | 时间变量 | 必填 |
| `unit(varname)` | 单位 id | 必填 |
| `adopt(varname)` | 首次处理期（缺失 = 从未处理） | 必填 |
| `kpre(#)` / `kpost(#)` | 事件窗口前后期数 | 3 / 2 |
| `controltype(str)` | `both` / `never` / `notyet` | `both` |
| `nythorizon(#)` | not-yet 控制组的最远采用期 | — |
| `weightvar(varname)` | 调查/抽样权重 | — |
| `datatype(str)` | `panel` / `repeated_cross_section` | `panel` |
| `weighttype(str)` | 权重类型（见下表） | `unit_weights` |

| weighttype | 含义 |
|---|---|
| `unit_weights` | 每个单位等权重（默认） |
| `population_between` | 人口权重（组间） |
| `pop_constant` | 人口权重（常数） |
| `pop_total_periods` | 人口权重（全期合计） |
| `pop_period_specific` | 人口权重（逐期） |
| `sample_share` | 样本份额权重 |

**Step 3：`stacked reg`** — Q 加权回归

```stata
* 事件研究（默认）
stacked reg uninsured, cluster(state)

* 单一 ATT
stacked reg uninsured, cluster(state) model(att)

* 交互固定效应（规范 stacked DiD 设定）
stacked reg uninsured, cluster(state) fe(interacted)

* 按 cohort 分解
stacked reg uninsured, cluster(state) bygroup

* 含协变量
stacked reg uninsured, cluster(state) covariates(income poverty)
```

| 选项 | 含义 | 默认 |
|---|---|---|
| `cluster(varname)` | 聚类变量 | — |
| `ref(#)` | 参考事件期 | -1 |
| `model(str)` | `eventstudy` / `att` | `eventstudy` |
| `fe(str)` | `saturated`（无 FE）/ `interacted`（unit×sub_exp + time×sub_exp） | `saturated` |
| `bygroup` | 按 cohort 分解估计 | 关闭 |
| `covariates(varlist)` | 额外协变量 | — |
| `absorb(fvlist)` | 高维 FE（传给 reghdfe） | — |

### 设计诊断：`stacked summary`

`stacked summary` 输出每个 cohort 的 ATT、SE、权重，并报告两个聚合恒等式：

```stata
stacked summary uninsured, cluster(state)
```

输出：
- 每行一个 cohort：N obs、treated units、precision weight (w_a^S)、corrective Q-weight (w_a^T)、ATT、SE
- 汇总行：D 统计量（设计差距）、D-gap（最大单 cohort 偏差）
- 两个恒等式：precision 加权和 = 未加权 TWFE 系数；Q 加权和 = 目标 ATT

**D 统计量解读**：D = Σ|w_a^S - w_a^T|。D ≈ 0 → 未加权 TWFE 和 Q 加权估计差异小；D 大 → 未加权 TWFE 隐含权重与目标权重严重不匹配，TWFE 偏误风险高。

### 按 cohort 分解：`stacked reg, bygroup`

```stata
stacked reg uninsured, cluster(state) bygroup
stacked plot, bygroup                    // 叠加图（marker 大小 = 权重）
stacked plot, bygroup combine(facet)     // 分面图（每 cohort 一个面板）
stacked levels uninsured, bygroup        // 每 cohort 加权均值
```

`bygroup` 存储在 `r(group_att)`：每行一个 cohort（sub_exp, att, se, lb, ub, weight）。恒等式：pooled ATT = Σ(weight × cohort ATT)。

### 大数据支持（DuckDB/Parquet）

```stata
* 连接 DuckDB（一次性下载 JDBC 驱动 ~75MB）
stacked duckconnect, download

* 从 Parquet 构建堆叠（不进内存）
stacked build, parquet("data/*.parquet") time(year) unit(state) adopt(adopt_year) kpre(3) kpost(2)

* 从压缩数据回归（秒级，支持 100M+ 行）
stacked reg outcome, duck cluster(state)
```

### 与 diff-diff 的对应关系

`stacked` ≈ diff-diff 的 `StackedDiD`。diff-diff 用 `stacked` 作为 Stata 端的交叉验证锚点。

### 何时用 StackedDiD vs csdid/hdidregress

| 场景 | 推荐 | 理由 |
|---|---|---|
| 要设计诊断（看 TWFE 偏误来源） | **StackedDiD** | `stacked summary` 的 D 统计量直接报告权重差距 |
| 要按 cohort 分解（权重透明） | **StackedDiD** | `bygroup` + `plot` 直观展示每个 cohort 的贡献 |
| 要 DR/IPW/Reg 三方法 | `csdid` | StackedDiD 无此选项 |
| 要非线性模型 | `jwdid` | StackedDiD 仅支持线性 |
| 要官方内置 | `hdidregress` | Stata 18+ |
| 大数据（100M+ 行） | **StackedDiD** | DuckDB 后端秒级回归 |

