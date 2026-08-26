---
name: stata-identification-common-assumptions
description: 跨 RCT、RDD、IV、面板政策设计与 selection-on-observables 的共同识别假设审计。
---

# Common identification assumptions

每条都严格按“定义 → 需要的证据 → 失败后能说什么”审计。统计诊断只能补充证据，不能单独证明假设。

## 1. Consistency

- **定义**：单位在实际接受的处理水平下，其观测结果等于该处理水平对应的潜在结果；treatment 的版本、剂量、起点和暴露窗口必须定义清楚。
- **需要的证据**：处理操作化与记录规则；不同实施版本是否可合并；outcome 测量时点与处理时点；跨场所 / 人群的版本差异审计。
- **失败后能说什么**：原 treatment effect 对象没有清晰定义。可描述不同标签或版本与 outcome 的关联，但在重新定义 treatment / estimand 前停止因果解释。

## 2. SUTVA / no interference

- **定义**：一个单位的潜在结果不受其他单位 treatment 状态影响，且 treatment 没有未区分的多个版本。
- **需要的证据**：干预传播路径、网络 / 地理接触、市场均衡或 spillover 机制；cluster assignment 与污染记录；与科学问题匹配的 exposure mapping。
- **失败后能说什么**：不能继续解释原个体级 estimand。应重写 exposure mapping，改用 cluster / spillover / policy estimand；未解决前只能报告观测关联或明确受干扰的描述结果。

## 3. Design-specific exchangeability

- **定义**：目标反事实比较的可比性来自具体研究设计，而不是来自“控制了很多变量”。其形式随设计改变：RCT 的随机化独立性；RDD 的 cutoff 局部连续性与不可精确操纵；IV 的 independence / exclusion；standard DID 的 parallel trends；`synth` 的 donor 与 pre-fit 条件；`sdid` 的 weighting、latent-factor / regularity 条件；selection 的 conditional exchangeability。
- **需要的证据**：随机分配协议与 attrition 审计；cutoff 规则、时间线和操纵可能性；IV 制度来源与 outcome 通道审计；政策前趋势、比较组形成和同期冲击；donor pool / pre-fit；`sdid` 的 comparison structure 与方法条件；selection 中处理前共同原因的 substantive causal map。balance、pretrend、density、first-stage 和 overidentification 结果只能作为支持性诊断。
- **失败后能说什么**：当前方法分支不能识别目标效应。返回 decision tree 检查同级或下一分支；若没有其他可信设计，只能保留描述 / 关联，不能靠 estimator 名称修复。

## 4. Positivity / overlap

- **定义**：在目标总体相关的 covariate strata、cutoff 邻域或设计比较集合中，需要的 treatment / comparison 状态具有正概率或存在有效比较单位。
- **需要的证据**：各 treatment 状态的实际支持、propensity 分布、cutoff 两侧观测、cohort-time comparison cells、donor / control 可用性，以及极端权重和外推距离。图形与汇总是诊断，不是 exchangeability 的证明。
- **失败后能说什么**：缩小目标总体或时间 / running-variable 邻域，改变 estimand，或停止该因果问题。不能用 matching、weighting 或“double robust”标签创造不存在的比较。

## 5. Estimand

- **定义**：明确 treatment contrast、目标总体、时间窗口和效应汇总对象，例如 ATE、ATET、complier LATE、cutoff 处局部效应、group-time ATET 或政策路径效应。
- **需要的证据**：研究问题与 assignment / eligibility / uptake 机制的对应关系；目标总体纳入规则；处理与 follow-up 窗口；异质效应如何汇总。RCT 也必须先定义 estimand，随机化通常支持 ITT 但不自动锁死唯一对象。
- **失败后能说什么**：不允许只报告未限定的“处理效应”。可以报告清楚命名的均值差或回归关联；在明确“对谁、何时、哪种处理对比”前停止因果 effect 表述。

## 6. Power / precision，不是 identification

MDE、sample size、standard error 与 confidence-interval width 只回答研究在既定设计和 estimand 下能多精确地排除或检测多大效应：

- 小样本、宽 CI 或较大 MDE 表示可能不精确，不自动证明设计无效；
- 大样本、窄 CI、小 p 值或较小 MDE 不修复 exchangeability、exclusion、parallel trends、no interference 或 positivity；
- 论文应把 identification assumptions 与 power / precision 分成两个小节；不得在假设清单中用 MDE 替代 design evidence。

## 7. 可执行教学形状（供 Ticket 06 verify）

下面只验证一个已声明随机 DGP 的数值恒等式和样本内支持；它不证明现实研究的 no interference 或 exchangeability：

```stata
version 19.5
clear
set seed 20260825
set obs 2000
generate byte treat = runiform() < 0.5
generate double y0 = rnormal()
generate double y1 = y0 + 0.5
generate double y = cond(treat, y1, y0)
assert y == y1 if treat == 1
assert y == y0 if treat == 0
summarize treat, meanonly
assert r(mean) > 0.45 & r(mean) < 0.55
```

这些 `assert` 只能核对模拟生成合同；正式验证与日志属于 Ticket 06，不能把本代码围栏本身当作已运行证据。
