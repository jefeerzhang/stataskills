---
name: stata-selection-paper-writing
description: selection-on-observables 论文写作参考；在报告 IPWRA ATET 主结果、独立 balance/overlap 诊断和外推限制时加载。
---

# Selection-on-observables 论文写作

## 何时用

需要把横截面 binary-treatment 分析写成可审计的论文方法、主表、诊断附表与限制段时使用。

## 主表最小代码

```stata
version 19.5
estimates table ipwra_atet, b(%9.3f) se(%9.3f) stats(N)
```

本 reference 假定估计与诊断已按主 skill 和 [balance-overlap.md](balance-overlap.md) 完成。主表只报告已存储的 `ipwra_atet` **ATET 原尺度**；balance/overlap 结果留在独立 log 或附表，不复制完整估计诊断链。

## 关键陷阱

- **陷阱**：主表只列显著性、不写 estimand。→ **触发**：读者无法知道结果是 ATE 还是 ATET。→ **Fix**：表题/脚注明确 ATET、outcome 单位、处理定义与样本。→ **验证**：表注出现 ATET 与原尺度。
- **陷阱**：诊断被写成假设证明。→ **触发**：balance/overlap 后写“因此识别成立”。→ **Fix**：写“诊断与观测可比性一致，但不能证明 selection-on-observables、无未观测混杂或 positivity 假设”。→ **验证**：限制段包含这句逻辑。
- **陷阱**：无限外推。→ **触发**：把 treated-support 的 ATET 写成全社会效应。→ **Fix**：限定到估计样本、处理组与共同支持；说明换人群/制度/时代需新论证。→ **验证**：结论含明确外推边界。

## 边界 / 论文说明

最低报告内容：处理与 outcome 定义；所有 covariates 的处理前时间顺序；selection-on-observables、positivity/overlap、SUTVA 与独立性论证；IPWRA 两个模型的 predictors；ATET 原尺度、SE、CI、N；独立 balance 附表；overlap 诊断；缺失处理、限制与外推范围。

可用表述：

> 在给定处理前协变量且 selection-on-observables、positivity 与 SUTVA 假设成立时，IPWRA 估计处理组平均处理效应（ATET）。协变量 balance 与 propensity overlap 作为诊断记录，但不能证明这些识别假设，也不能排除未观测混杂。

不要把 `teffects aipw` 写成 IPWRA，也不要把 `hdidregress aipw` 写成横截面 estimator；时间处理/错时处理转 `stata-did`，总体识别路由转 `stata-identification`。
