---
name: stata-selection-teffects-nnmatch
description: 官方 teffects nnmatch 参考；在需要基于协变量距离的 nearest-neighbor matching 对照时加载。
---

# 官方 `teffects nnmatch`

## 何时用

当 matching 需要直接基于预处理协变量距离，而不是 propensity score 时加载。它是 IPWRA 后的官方对照，不是默认主估计。

## 强制路径 / 最小代码

```stata
version 19.5
teffects nnmatch (y x1 x2 x3 x4) (treat), atet nneighbor(1) ///
    biasadj(x1 x2 x3 x4) metric(mahalanobis) ///
    vce(robust, nn(2)) osample(nn_osample)
estimates store nnmatch_atet
```

第一个括号放 outcome 与 matching covariates，第二个括号放 treatment；协变量必须是处理前变量。`nneighbor(1)` 指定每个 observation 的最近邻数量；ties 可能使实际生成的邻居对象多于请求数量。`biasadj(varlist)` 对多于一个连续 matching covariate 的大样本 bias 做线性校正；不能把它理解成对未观测混杂的修复。

## Metric、bias adjustment 与推断边界

本机 StataNow 19.5 `[CAUSAL] teffects nnmatch` help/source 核实的 `metric()` 选项为：

- `mahalanobis`：逆样本协方差距离，默认；处理不同尺度与协方差。
- `ivariance`：逆对角样本协方差距离；忽略变量间协方差。
- `euclidean`：单位矩阵距离；对变量尺度敏感，使用前需有明确标准化/尺度理由。
- `matrix matname`：用户提供缩放矩阵；必须说明矩阵构造。

`biasadj()` 是 Abadie–Imbens bias adjustment；只写入有理论和时间顺序依据的处理前 matching covariates。`vce(robust, nn(#))` 使用指定数量的同处理组邻居计算 robust Abadie–Imbens SE；`vce(iid)` 是 iid SE。官方 help 明确 bootstrap 不为该 estimator 提供可靠 SE，因此不要用 bootstrap 替代官方 VCE。

`caliper(#)` 限制最大匹配距离；若有效邻居不足，估计可能退出。`osample(newvar)` 标记违反 overlap 的 observations；`generate(stub)` 保存邻居 observation numbers，ties 可能生成多于 `nneighbor()` 的变量。报告有效 estimation sample、`osample()`、metric、邻居数、bias-adjustment variables 与 VCE。NN 结果只对当前 covariate metric、尺度、共同支持和目标 ATET 有效，不自动外推到无支持人群。

以上 syntax 已在正式教学数据 `data/selection/teaching-treatment.dta` 的 `preserve` 临时副本实测通过；ATET = 0.4447961，robust SE = 0.0761203，`e(metric)` 为 `mahalanobis`，`e(bavarlist)` 为 `x1 x2 x3 x4`，并成功生成 `nn_osample`。

## 关键陷阱

- **陷阱**：把 propensity-score covariates 的括号结构照抄到本命令。→ **触发**：处理变量后再列协变量。→ **Fix**：把 `x1 x2 ...` 放 outcome 括号。→ **验证**：help 与命令结构一致。
- **陷阱**：切换模型后误读当前结果。→ **触发**：NN 后继续运行其他 estimator，`e()` 被覆盖。→ **Fix**：NN 后立即 `estimates store nnmatch_atet`；需要回看时 `estimates restore nnmatch_atet`。→ **验证**：`estimates dir` 中存在该模型；不调用 propensity-score 专用的通用 balance 命令。
- **陷阱**：认为最近邻自动解决无共同支持。→ **触发**：极端 covariate distance/稀疏 treated。→ **Fix**：检查支持域与匹配质量，必要时不作因果外推。→ **验证**：保留样本/匹配诊断记录。

## 边界 / 论文说明

NN matching 对尺度、距离度量、ties、邻居数与有限样本敏感；报告 covariates、邻居数、ATET 原尺度、有效样本及诊断。balance 改善不等于无未观测混杂。
