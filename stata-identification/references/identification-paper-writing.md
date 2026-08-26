---
name: stata-identification-paper-writing
description: 可审计的识别策略论文写作骨架；区分 design evidence、支持性诊断、不可由诊断证明的假设与外推边界。
---

# Identification paper writing

写作顺序固定为 estimand → 机制 → 假设 → 支持性诊断 → 诊断不能证明的部分 → 目标总体 → 外推边界。不要从 estimator 名称或显著性开始。

## 1. Estimand

必须写清：

- treatment / exposure contrast；
- outcome 与 follow-up window；
- unit 与目标总体；
- 效应对象：ATE、ATET、LATE、cutoff 局部效应、group-time ATET 等；
- 时间和人群上的汇总方式。

模板：

> 本研究目标 estimand 是 [目标总体] 中，[时间窗口] 内 [treatment contrast] 对 [outcome] 的 [ATE / ATET / LATE / local effect / group-time ATET]。

## 2. Assignment / institutional mechanism

解释为何 treatment、eligibility、instrument 或 policy timing 产生目标反事实比较。写可审计事实：规则制定者、实施时间、资格算法、随机化单位、执行偏差、comparison units 的来源。变量名 `instrument`、`cutoff` 或 `policy_year` 不是机制说明。

模板：

> 比较由 [随机化协议 / 预先阈值规则 / 工具变量制度来源 / 政策实施与 comparison structure / 处理前混杂测量计划] 形成。关键时间线为 [规则确定、处理发生、结果测量]。

## 3. Identification assumptions

把共同假设和方法特定假设分开列出：

- consistency 与 treatment versions；
- SUTVA / no interference；
- design-specific exchangeability；
- positivity / overlap 或有效 comparison set；
- 与 estimand 对应的附加条件，例如 IV-LATE 的 monotonicity，RDD 的 continuity / no precise manipulation，standard DID 的 parallel trends，或 `synth` / `sdid` 的方法条件。

不要写“控制变量充分，所以无混杂”或“采用某 estimator，所以识别成立”。

## 4. Supporting diagnostics

诊断必须写成“与设计相容 / 未发现特定反例 / 提供支持性证据”，不能写成证明：

| 诊断 | 可以支持的窄结论 | 不能证明 |
|---|---|---|
| balance | 已观测基线变量在指定比较下的样本平衡 | 无未观测混杂、随机化完整性或 SUTVA |
| pretrend / event-study leads | 观测到的处理前 outcome pattern 与某些趋势偏离不冲突 | 处理后 counterfactual parallel trends、无 anticipation、无同期冲击 |
| density / manipulation test | cutoff 附近未发现特定形式的 sorting / density jump | continuity、完全无操纵或所有协变量平衡 |
| first stage | instrument / encouragement 与 treatment 有相关性 | independence、exclusion、monotonicity 或有效 LATE 外推 |
| overidentification test | 在额外工具和模型条件下未拒绝一组矩条件 | 每个工具都外生、exclusion 成立；恰好识别时更没有该检验 |

安全句式：

> [诊断] 的结果与 [窄设计含义] 相容，但不能证明 [不可检验假设]；后者主要依赖 [制度 / 设计证据]。

## 5. What diagnostics cannot establish

单独成段说明：

- 哪些假设没有直接统计检验；
- 哪些制度通道仍可能违反 exclusion / no interference / no anticipation；
- 哪些未观测混杂、处理版本、样本选择或 spillover 仍可能存在；
- 哪些结果只对局部人群、compliers、cutoff 邻域、treated units 或特定 cohort-time cells 有效。

若关键假设无法辩护，必须改写为 association / descriptive difference，不得用“suggests a causal effect”绕过 stop causal。

## 6. Target population

明确样本与 estimand 总体是否一致：

- RCT：被随机化 / 被邀请 / 实际接受者中的哪一类；
- RDD：cutoff 邻域；
- IV：由工具改变 treatment 的 compliers；
- DID / synth / sdid：哪些 treated units、cohorts、时期和 comparison units；
- selection：满足共同支持且 adjustment set 可用的目标总体，ATET 时尤其明确 treated population。

## 7. Extrapolation boundary

至少报告以下边界：

- 人群、地点、制度与时间范围；
- treatment version 与执行强度；
- 局部 estimand 能否推广到其他支持区域；
- interference、general-equilibrium 或 policy-scale change 的风险；
- 样本删减、overlap trimming 或 donor restrictions 改变了哪个目标总体。

模板：

> 结论直接适用于 [目标总体 / 时间 / 制度]。向 [其他人群 / cutoff 之外 / noncompliers / 其他政策环境] 外推需要额外的 effect-transportability 假设，本研究的诊断不能验证这些假设。

## 8. Power / precision 的独立表述

MDE、sample size、SE 与 CI width 放在 precision 小节：

> 在已声明的设计与 estimand 下，估计的 [SE / CI / MDE] 描述精度；它不验证 identification assumptions。反之，较宽 CI 表示信息有限，不等于设计假设必然失败。

## 9. 最终审计清单

- [ ] estimand 指明 treatment contrast、总体与时间窗口；
- [ ] assignment / institutional mechanism 可审计；
- [ ] assumptions 与 supporting diagnostics 分开；
- [ ] balance、pretrend、density、first-stage、overidentification 均未写成证明；
- [ ] 明说诊断不能证明的部分；
- [ ] 目标总体和外推边界明确；
- [ ] MDE / sample size / SE / CI 只位于 power / precision；
- [ ] gate 失败时没有因果措辞。
