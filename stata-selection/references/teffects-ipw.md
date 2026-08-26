---
name: stata-selection-teffects-ipw
description: 官方 teffects ipw 参考；在需要 inverse-probability weighting 作为明确对照或权重敏感性分析时加载。
---

# 官方 `teffects ipw`

## 何时用

主 IPWRA 完成后，需要报告只依赖 treatment model 的 IPW 对照，或研究问题明确要求 propensity weighting 时加载。

## 强制路径 / 最小代码

```stata
version 19.5
teffects ipw (y) (treat x1 x2 x3 x4), atet
estimates store ipw_atet
```

通用 balance/overlap 诊断只在 [balance-overlap.md](balance-overlap.md) 集中维护；本 estimator reference 不重复调用。

`y` 在 outcome 括号；`treat` 与处理前 predictors 在 treatment 括号。`atet` 指处理组平均处理效应；overlap 是 postestimation，不带 `atet`。

## 关键陷阱

- **陷阱**：把 IPW 当双重稳健。→ **触发**：只拟合 treatment model 却写“任一模型正确即可”。→ **Fix**：IPW 依赖 propensity/treatment model 正确指定；双重稳健说明只放在 IPWRA/AIPW。→ **验证**：方法表区分 IPW 与 IPWRA。
- **陷阱**：极端权重仍强行解释。→ **触发**：overlap 差、预测概率接近 0/1。→ **Fix**：记录 positivity 风险，重审设计/支持域；不声称 IPWRA 能修复。→ **验证**：报告 overlap 与限制。
- **陷阱**：使用 `group(treat)` 或 `eform`。→ **触发**：混入 DID/OR 语法。→ **Fix**：按官方括号语法并报告 ATET 原尺度。→ **验证**：估计命令无这两个选项。

## 边界 / 论文说明

IPW 对 treatment model misspecification 敏感，极端权重会放大方差。报告 treatment model、共同支持、权重诊断与估计样本；IPW 只作明确的对照，不默认取代 IPWRA。
