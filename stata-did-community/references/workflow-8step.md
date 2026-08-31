---
name: stata-did-community-workflow-8step
description: DID 8 步 practitioner 工作流参考：Baker et al. (2025)《How Practice Meets Theory in DiD》。覆盖定义目标参数、陈述识别假设、测试平行趋势、选估计量、估计并核对聚类数、敏感性分析、异质性、稳健性。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-workflow-8step

> **加载时机**：主 SKILL.md 决策树已读完，跑一个完整的 DID 研究项目需要从目标到稳健性串起来时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 8. 8 步 practitioner 工作流（Baker et al. 2025）

跳过诊断步骤 = 不可靠结论。以下 8 步是 `igerber/diff-diff` 项目从学术最佳实践中凝练的工作流，**全部 8 步都能在 Stata + stataskills did 内执行**——`diff-diff` 只是把流程命名约定化了，Stata 生态每个命令都能映射。

### 步骤 1 — 定义目标参数

明确你要估计什么：

| 目标参数 | Stata 估计量 |
|---|---|
| ATT（平均处理效应） | `didregress` / `xtdidregress`（见 `stata-did` skill） |
| ATT(g, t)（cohort × 时期） | `hdidregress` + `estat aggregation, cohort`（见 `stata-did` skill） |
| ATT_es(e)（事件研究） | `hdidregress` + `estat aggregation, dynamic`（见 `stata-did` skill） |

明说是否加权（绝大多数情况下未加权；survey 数据见 [Roth et al. 2023](https://www.nber.org/papers/w31203)）。

### 步骤 2 — 陈述识别假设

至少明说三种：

- **平行趋势**（哪种变体？无条件的 / conditional on covariates / PT-GT-Nev / PT-GT-NYT）— 详见 Roth et al. (2022) § 3.1。
- **无预期**（no anticipation）：处理前一期，处理组不改变行为。
- **重叠**（overlap）：处理组与对照组在协变量分布上有共同支撑。

### 步骤 3 — 测试平行趋势

```stata
didregress (y) (treat), group(id) time(t)
estat ptrends                          // 数字检验（注意 staggered 时此检验不可靠）
estat trendplot                        // 图形诊断
```

**关键提醒**（Roth 2022 "Pretest with Caution"）：

`estat ptrends` 的 p > 0.05 **不等于**平行趋势假设成立：

1. **不显著的 pre-trends 不证明 PT** —— 只是没证据拒它；研究功效不足时永远不显著。
2. **staggered 设计下 `estat ptrends` 失效** —— 检验的是"加总 pre-period 系数=0"，与 staggered
   异质处理效应所需的 pre-trend-by-cohort 检验不同；正确做法是看 CS / SA 事件研究的
   pre-period 系数（`estat event` 的 e < 0 部分联合检验）。
3. **pretest 影响后续推断** —— "先检验、再报告 CI"违反 pretest 独立性；post-selection CI 偏宽。

**何时汇报**：
- ✅ 论文 method 节明说"我们跑了 Roth 2022 警示的 staggered pre-trend 检查
  （csdid `estat event` 报告 e<0 系数联合检验）"
- ❌ 不要单报 `estat ptrends` 的 p 值当作 PT 成立的证据。

**R 包 `pretrends`** 提供正式 pretest-adjusted CI；**Stata 无等价包**——如需 post-selection
调整，目前只能手算或迁 R。本文档只做警示性提醒，不引入新命令。

**文献**：Roth, J. (2022). "Pretest with Caution: Event-Study Estimates after Testing for
Parallel Trends." *American Economic Review: Insights*, 4(3), 305-322.
https://doi.org/10.1257/aeri.20210236

### 步骤 4 — 选估计量

| 设计特征 | 推荐估计量 | Stata 命令 |
|---|---|---|
| simple 2x2 | DiD / TWFE | `didregress` / `xtdidregress`（见 `stata-did` skill） |
| staggered adoption | CS / SA / BJS（**不是** plain TWFE） | `hdidregress aipw` / `xthdidregress aipw`（见 `stata-did` skill） |
| **可逆处理**（开关型） | DCDH | `ssc install did_multiplegt`（第 5 节） |
| **非二元处理**（连续/多值） | DCDH | `ssc install did_multiplegt`（第 5 节） |
| **无 stayers**（所有单位最终处理） | DCDH had | `did_multiplegt (had)`（第 5 节） |
| staggered + 想做 DR/IPW/Reg 三方法对照 | CS 估计量 | `ssc install csdid`（第 1 节） |
| staggered + 非线性结果变量（计数/二元） | ETWFE | `ssc install jwdid`（第 1 节） |
| staggered + 想要 leaveout 方差修正 / 单位特定趋势 / 灵活 FE | BJS 插补法 | `ssc install did_imputation`（第 1 节） |
| 一个或极少处理单位 + 较长 pre-period + 可辩护 donor pool | Synthetic Control | `ssc install synth`（第 2 节）；用 placebo / permutation 推断 |
| 充分 pre / post + untreated 或 not-yet-treated comparison units；单个或多个处理单位、当前实现支持的多个处理日期 | Synthetic DiD | `ssc install sdid`（第 3 节）；审计单位 / 时间 weighting、latent-factor / regularity 与方法特定推断条件 |
| 复杂共同因子 | TROP | `ssc install trop` |
| 内生选择 + 因子 | TROP / Imputation | 社区包 |

跑前先用 `estat bdecomp`（错时）或 `reghdfe`（手动 TWFE）诊断 TWFE 偏误大小。

### 步骤 5 — 估计并核对聚类数

```stata
xtdidregress (y x1 x2) (treat), group(id) time(t) vce(cluster id)
* 或：didregress (y x1 x2) (treat), group(id) time(t) wildbootstrap(reps(99) rseed(...))
```

**先打印 cluster 数**：

```stata
levelsof id, local(ids)
display "N clusters = `:list sizeof ids'"     // 至少 ≥ 50 才用 cluster-robust；< 50 改 wildbootstrap / DLang
```

规则（Bertrand et al. 2004）：聚类数 < 50 → wild bootstrap 或 `aggregate(dlang)`；≥ 50 → 默认 cluster-robust SE。

### 步骤 5b — 面板 MDE / 功效分析（投稿前必做）

**Why**：审稿人最常问"你的样本能检测多小的效应"；**事前**做 MDE 比**事后**解释功效不足更稳。

**两套方法**（按精度需求选）：

1. **Analytical (Bloom 1995)**：闭式公式，快速但假设均匀效应
   - 输入：N、T、σ_τ、σ_ε、α、power_target
   - 输出：MDE in SD units（论文"sample size justification"段引用）

2. **Simulation (Burlig-Preonas-Woerman 2020, panel 版)**：DGP 内嵌异质 ATT + 聚类结构
   - 用 `simulate` 命令 + Monte Carlo（500+ reps）
   - 输出：power vs ATT 曲线，匹配你实际估计量（TWFE / csdid / did_imputation）

完整 do-file 模板见 [references/power-analysis-template.do](references/power-analysis-template.do)。文件含两套方法的完整实现，使用时逐段复制到自己的 do-file 跑（不要 do 整个文件，会刷数据）。

**典型审查答复**：

> "With N=200 clusters × T=10 periods and ATT of 0.2 SD, our design achieves 80% power
> to detect effects of ~0.09 SD (analytical Bloom 1995, uniform-effect assumption) and
> ~70-90% power at 0.2 SD under a staggered heterogeneous-ATT DGP with ρ=0.5 within-cluster
> correlation (simulation, Burlig et al. 2020)."

### 步骤 6 — 敏感性分析

不能只报主估计。必报：

- **Honest DiD**（Rambachan & Roth 2023）——平行趋势假设可能违反时的稳健 CI 上界：

  ```stata
  * 需要 ssc install honestdid（社区包）
  didregress (y) (treat), group(id) time(t)
  honestdid, m(0)         // M=0 表示允许 PT 违反的大小为 0（即原 PT 成立）
  honestdid, m(0.5)       // M=0.5 允许 PT 违反幅度 ≤ 0.5 SD（更宽松）
  ```

  报告 `M=0` 与 `M=0.5` 下的稳健 CI——这是审稿人最爱要的稳健性检查。
- **Placebo tests**（虚假检验）：用未受处理的时间窗口做"伪政策"分析，看系数是否接近零。
- **协变量敏感性**：带 vs 不带协变量两套结果对比，说明识别是否由条件分布驱动。

### 步骤 7 — 异质性

```stata
hdidregress aipw (y x1) (treat), group(id) time(t)

* 按 cohort 聚合（处理在哪一年入场）
estat aggregation, cohort graph

* 按事件研究聚合（暴露期长度）
estat aggregation, dynamic graph
```

**不要只报单一 ATT**——不同 cohort 的处理效应可能差异巨大（异质性处理效应是错时 DID 偏误的根源）。

### 步骤 8 — 稳健性

至少跑 2-3 个估计量对照：

- `didregress`（TWFE）vs `hdidregress aipw`（双重稳健）vs `csdid`（CS 估计量）
- 报"带协变量"与"不带协变量"两套结果
- 报 pre-trends 与稳健 CI 上下界

在论文里把这些数字放进一个对比表，让读者看估计量的稳定范围——单一估计量不可信。

### 工作流总结

| 步 | 输出 |
|---|---|
| 1 | 目标参数定义 |
| 2 | 假设明文化 |
| 3 | 平行趋势检验 + 图 |
| 4 | 估计量选择（含 TWFE 偏误诊断） |
| 5 | 估计结果 + 聚类数核对 |
| 6 | Honest DiD + placebo + 协变量敏感性 |
| 7 | 异质性（cohort × event-time） |
| 8 | 多估计量稳健性对照 |

> **关键提醒**：`igerber/diff-diff` 的 `get_llm_guide("practitioner")` 返回该工作流的 Python API 映射——可直接喂给 AI Agent 做 DID 自动化分析；Stata 用户可手按此 8 步操作。

