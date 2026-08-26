---
name: stata-selection-teffects-psmatch
description: 官方 teffects psmatch 参考；在二元处理、处理前协变量的 propensity-score matching 对照场景加载。
---

# 官方 `teffects psmatch`

## 何时用

主 IPWRA 已完成后，需要官方 propensity-score nearest-neighbor matching 作为明确的敏感性/方法对照时使用。它不是默认主估计。

## 强制路径 / 最小代码

```stata
version 19.5
teffects psmatch (y) (treat x1 x2 x3 x4), atet nneighbor(1) caliper(0.2)
estimates store psmatch_atet
```

通用 balance/overlap 诊断只在 [balance-overlap.md](balance-overlap.md) 集中维护；本 estimator reference 不重复调用。

`teffects psmatch` 在第一个括号放 outcome，在第二个括号放 binary treatment 与 propensity covariates；`atet` 是处理组平均处理效应。运行 balance/overlap 前必须已有估计结果。

## 关键陷阱

- **陷阱**：把 `teffects psmatch` 当主结果。→ **触发**：未先运行 IPWRA。→ **Fix**：主结果固定 `teffects ipwra ..., atet`，本命令只做预先说明的对照。→ **验证**：主表第一列/标题为 `ipwra_atet`。
- **陷阱**：把 `group(treat)` 或 `eform` 带入。→ **触发**：从 DID 或 logit 表复制选项。→ **Fix**：使用上面的括号结构与原尺度 ATET。→ **验证**：命令不含 `group()`、`eform`。
- **陷阱**：把平衡诊断写成识别证明。→ **触发**：balance 改善后声称无未观测混杂。→ **Fix**：同时报告 selection-on-observables 与 overlap 假设。→ **验证**：限制段明确诊断不能证明假设。

## 边界 / 论文说明

匹配估计的是当前匹配规则与共同支持下的 ATET；匹配结果对距离、ties、邻居与有限样本敏感。报告匹配规则、样本量、原始/加权 balance 与 overlap，并将其与 IPWRA 原尺度主结果分开。
