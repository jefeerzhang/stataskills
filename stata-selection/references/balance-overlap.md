---
name: stata-selection-balance-overlap
description: selection balance 与 overlap/positivity 诊断参考；在解释 tebalance summarize、teffects overlap 和共同支持边界时加载。
---

# Balance 与 overlap/positivity

## 何时用

主 IPWRA 或支持这些 postestimation 的 propensity-based `teffects` estimator 完成后，单独记录协变量平衡与 propensity-score overlap 诊断时使用。`teffects nnmatch` 不适用本通用路径；NN 只做其自身距离、ties、邻居数、bias adjustment 与有效匹配样本诊断。

## 强制路径 / 最小代码

```stata
version 19.5
teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
estimates store ipwra_atet
tebalance summarize
teffects overlap
```

`tebalance summarize` 与 `teffects overlap` 都是 postestimation；本路径明确用于 `teffects ipwra`、`teffects ipw` 与 `teffects psmatch` 这三类 propensity-based 结果，并在诊断前 `estimates restore <目标模型>` 以固定归属。`teffects overlap` 不带 `atet`。`teffects nnmatch` 不支持这条通用路径，不得在 NN 后调用 `tebalance`。

## 关键陷阱

- **陷阱**：balance = identification。→ **触发**：标准化差异变小就宣称因果成立。→ **Fix**：balance 只反映已观测 covariates 的可比性；仍需制度论证 selection-on-observables。→ **验证**：报告将诊断与识别假设分开。
- **陷阱**：忽略 positivity。→ **触发**：treated/control 的 propensity 支持域几乎不重叠、预测概率接近 0/1。→ **Fix**：重审目标人群、处理定义与共同支持；不把估计外推到无支持区域。→ **验证**：保留 overlap 输出并写明外推边界。
- **陷阱**：在估计前运行 postestimation。→ **触发**：`tebalance`/`teffects overlap` 报无结果。→ **Fix**：先估计并 store，再诊断。→ **验证**：日志顺序为 estimate → store → balance → overlap。

## 边界 / 论文说明

Balance 诊断的是观测协变量；overlap 诊断的是处理概率支持。两者都不能证明无未观测混杂、SUTVA 或 treatment model 正确。不要用图形替代数值与文字记录；需要图形时默认英文，中文标签先询问。
