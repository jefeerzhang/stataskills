---
name: stata-selection-teffects-ipwra
description: 官方 teffects ipwra 参考；在 selection-on-observables 横截面分析中指定和解释默认 IPWRA ATET 主估计时加载。
---

# 官方 `teffects ipwra`

## 何时用

横截面、binary treatment、处理前可观测混杂且目标是 treated population 的平均处理效应时使用；这是 `stata-selection` 的默认主估计。

## 强制路径 / 最小代码

```stata
version 19.5
teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
estimates store ipwra_atet
```

通用 balance/overlap 诊断只在 [balance-overlap.md](balance-overlap.md) 集中维护；本 estimator reference 不重复调用。

第一括号是 outcome regression predictors，第二括号是 treatment model predictors；两者可以不同，但差异必须有设计理由。`estimates store` 紧跟估计命令。

## 双重稳健前提

在 treatment model 或 outcome model 至少一个正确指定时，IPWRA 对相应模型 misspecification 具有双重稳健性；仍需一致的 treatment/outcome 定义、无未观测混杂（给定协变量）、positivity/overlap、SUTVA/独立性与正确的处理前时间顺序。它不能修复未观测混杂、overlap 失败、spillover、错误函数形式同时失配或 post-treatment controls。

不要把 `teffects aipw` 简称为 IPWRA：AIPW 是另一种 official estimator；`hdidregress aipw` 是 DID 的时间/组结构命令。三者在文档与表格中分开命名。

## 关键陷阱

- **陷阱**：估计前 `tebalance`。→ **触发**：尚无 e-class treatment-effects results。→ **Fix**：估计 → store → balance → overlap。→ **验证**：log 顺序可见。
- **陷阱**：把双重稳健说成“自动解决混杂”。→ **触发**：声称未观测混杂或 overlap 不重要。→ **Fix**：完整报告上述识别前提与失败边界。→ **验证**：限制段明确写出不能修复的情形。
- **陷阱**：默认 `eform`。→ **触发**：把 ATET 指数化。→ **Fix**：原 outcome 单位报告。→ **验证**：主表列名与单位不变。

## 边界 / 论文说明

报告两个模型的 predictors、ATET、标准误、估计样本、balance 与 overlap 的独立诊断。对 outcome/treatment model 做有理论依据的敏感性分析即可，不要机械堆叠全部 estimator。
