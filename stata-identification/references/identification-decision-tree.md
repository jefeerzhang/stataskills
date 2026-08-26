---
name: stata-identification-decision-tree
description: Identification router 的唯一完整顺序化 stop rules；用于通用设计选择、方法 gate 失败后的重新路由和停止因果声明。
---

# Identification decision tree

<!-- identification-stop-rules: full -->

本文件是运行时材料中完整 stop rules 的唯一权威副本。每一步都先区分两类信息：

- **数据列 / 关键词**：例如 `randomized` 标签、`cutoff` 列、名为 `instrument` 的变量、面板与 `policy_year`、大量 covariates。它们只触发检查。
- **可辩护制度设计证据**：例如可审计的随机分配协议、预先确定的阈值规则、工具变量的制度来源与通道审计、政策时间线和未处理比较来源、处理前混杂测量计划。只有这类证据连同数据支持，才能通过 gate。

路由前必须写明 treatment、outcome、unit、时间结构、处理时点、目标总体和 estimand。匹配到首个成立且关键条件可辩护的跨支柱 stop rule 即停止；面板政策支柱内部按下述规则处理 standard DID 与 `synth` / `sdid`。

## 1. 完整顺序化 stop rules

| 顺序 | 进入条件与必须证据 | 关键识别假设 | 失败去向 | Stop / 路由结果 |
|---|---|---|---|---|
| 1. RCT / 随机分配 | 有可审计的随机机制分配 treatment 或 encouragement；先定义 estimand，不因“随机”二字自动锁定对象 | 随机化完整性、consistency、SUTVA / no interference、attrition 可处理；随机化通常支持 ITT，但具体 estimand 取决于 assignment、uptake 与 outcome 定义 | 没有可信随机机制 → RDD；随机机制可信但其他关键条件不能辩护 → 不报告相应因果 estimand，有其他独立设计证据则返回 router 检查下一分支，否则 stop causal；随机 encouragement 且有 noncompliance → IV 分支检查 LATE 条件 | 只有随机机制及对应关键条件均可辩护时才停在随机设计并报告预先定义的 estimand；v1 不新建 RCT 估计 skill，常规结果模型可转 `stata-regression` |
| 2. RDD | 有预先确定的连续或细粒度 running variable 与 cutoff，treatment probability 在 cutoff 跳跃；有规则形成和时间先后证据 | cutoff 附近潜在结果连续、无精确操纵、局部 positivity；fuzzy RDD 另需 first stage 与 IV 类条件 | 条件不能辩护 → IV | `stata-rdd` |
| 3. IV | 候选工具确实改变 treatment，且制度机制能审计工具来源与所有可能的 outcome 通道 | relevance、independence、exclusion；LATE 解释另需 monotonicity 与 SUTVA / no interference，并明确 compliers 与目标总体 | 任一关键条件不能辩护 → 面板政策公共 gate | `stata-regression` 的 `iv.md`、`iv-testing.md`、`iv-identification.md` |
| 4. 面板政策公共 gate | 有明确政策 / 处理时点、处理前后信息，以及可定义的未处理 donor / control 或 not-yet-treated comparison 来源；政策时间线与样本构成可审计 | no anticipation、SUTVA / no interference、稳定构成，目标时点与比较单位可定义；仅有 panel / policy-year 列不够 | 公共 gate 失败 → 横截面 selection；通过 → 先检查 4a，4a 未通过时必须检查 4b | 留在面板政策支柱内分叉 |
| 4a. standard DID | 公共 gate 已通过；有足够处理组与对照组 / 可比较单位形成 DID 比较，并能为具体 timing 设计辩护 counterfactual trend | 与设计匹配的 parallel trends，以及相应 overlap、composition 和 treatment-timing 条件 | parallel trends 或其他本地条件失败 → 必须检查 4b，不得直接去 selection | 条件成立并选择 standard DID 时停在 `stata-did`；无需机械运行 `synth` / `sdid` |
| 4b. `synth` / `sdid` | 公共 gate 已通过且 4a 未通过，或研究问题明确要求该子分支；并满足至少一个方法入口：**`synth`** 通常是一个或极少处理单位、较长 pre-period、可辩护 donor pool；**`sdid`** 有充分 pre / post periods 和 untreated / not-yet-treated comparison units，可有单个或多个处理单位及当前实现支持的多个处理日期 | `synth`：donor 可比性、充分 pre-fit、无同期独特冲击、placebo / 推断条件；`sdid`：weighting、latent-factor / regularity 与方法特定推断条件。两者均不以 standard DID parallel trends 作为父 gate | `synth` 与 `sdid` 两个析取入口都失败 → 横截面 selection | `stata-did-community` 中对应 `synth` 或 `sdid` reference；不得把“少数处理单位”设为 `sdid` 必要条件 |
| 5. 横截面 selection-on-observables | 横截面、binary treatment；adjustment set 全为 pre-treatment；有 substantive evidence 支持所有共同原因已观测，目标总体内有有效比较 | consistency、SUTVA / no interference、conditional exchangeability、positivity / overlap、明确 estimand（本仓库主路径默认 ATET） | 任一条件无法辩护 → stop causal | `stata-selection` |
| 6. 无可信识别设计 | 前述所有进入条件或关键假设均失败，或只有列名 / 关键词而无制度设计证据 | 不适用；precision 不能替代 identification | 无下一因果分支 | 明确停止因果声明；可转 `stata-descriptives` 或 `stata-regression` 做描述 / 关联，但不得称 effect / impact / caused |

## 2. 分支执行补充

### 2.1 RCT estimand、关键条件与 noncompliance

随机化不把 estimand 锁死。先区分 assignment、actual uptake 和目标总体：

- treatment assignment 随机且关注“被分配”的效果时，通常报告 ITT；
- 不能因 random assignment 自动把 per-protocol / as-treated contrast 写成因果效应；
- 随机机制可信但 attrition、consistency、SUTVA / no interference 或其他对应关键条件无法辩护时，不报告相应因果 estimand；若另有独立的 RDD、IV、面板政策或 selection 设计证据，返回 router 继续检查，否则 stop causal；
- 若随机的是 encouragement、实际 uptake 有 noncompliance，转到 IV 分支。只有 relevance、independence、exclusion、monotonicity 与 SUTVA 可辩护时，才把 Wald / 2SLS 对象解释为特定 compliers 的 LATE。

### 2.2 面板政策公共 gate 与两个子分支

公共 gate 先于方法选择，但不包含 standard DID 的 parallel trends。通过公共 gate 后：

1. 先检查 standard DID 是否有足够处理 / 对照比较并可辩护 parallel trends；
2. standard DID 未通过时，必须检查 `synth` / `sdid` 的方法特定入口，之后才可离开面板政策支柱；
3. standard DID 已通过并据此停止时，不机械运行 `synth` / `sdid` 充当“稳健性”；用户明确点名后者时仍按 named-method 表直达并执行其本地 gate；
4. `synth` 与 `sdid` 是析取条件：少数处理单位通常支持检查 `synth`，不是 `sdid` 的范围限制。

## 3. Named-method trigger ownership

明确点名方法时直接进入对应 skill，并先执行其最短本地 gate；不要先绕本 router：

| 用户明确点名 | 直达入口 | 本地 gate 失败动作 |
|---|---|---|
| DID、事件研究 | `stata-did` | standard DID 未通过时先检查同一面板支柱的 `synth` / `sdid`；均不成立再返回 router |
| `csdid`、`jwdid`、`synth`、`sdid` | `stata-did-community` | 返回 router |
| RDD、断点、`rdrobust` | `stata-rdd` | 返回 router |
| IV、2SLS、`ivregress`、`ivreg2`、LATE | `stata-regression` 的 IV references | 返回 router |
| PSM、IPW、IPWRA、`teffects`、entropy balancing、`ebalance` | `stata-selection` | 返回 router |
| `psmatch2` | 先进入 `stata-selection` 并执行设计 gate；gate 通过后才读 `stata-selection/references/psmatch2.md` | selection gate 失败则返回 router；不得先读 reference 再补 gate |

## 4. Stop causal 的输出合同

停止时必须同时给出：

1. 哪个 gate 失败，以及缺少的是数据支持还是制度 / 设计证据；
2. 当前数据仍可支持的描述或关联问题；
3. 禁止使用的因果措辞；
4. 若可行，下一步需要收集的设计证据或重新设计方案。

不得用更复杂 estimator、更多 controls、更小 p 值、更窄 CI 或更小 MDE 绕过 stop causal。
