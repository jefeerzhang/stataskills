---
name: stata-selection-ebalance
description: Optional entropy-balancing 参考；在明确需要 covariate-moment balancing 的敏感性分析或复现旧研究时加载。
---

# Optional `ebalance`

## 何时用

明确需要 entropy balancing 的协变量矩平衡或复现已有研究时使用；不进入默认 IPWRA 主路径。

## 已核实最小路径

本机 `ebalance.ado` v1.5.4（2015-01-29）核实如下。以下主路径片段假定此前已有 `ipwra_atet`；主分析先完成 IPWRA 并 `estimates store ipwra_atet`，再进入本社区敏感性示例：

```stata
version 19.5
capture which ebalance
if _rc {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__"
}
else {
    preserve
    ebalance treat x1 x2 x3 x4, targets(1)
    assert e(convg) == 1
    tempvar esample_default
    generate byte `esample_default' = e(sample)
    confirm variable _webal
    assert !missing(_webal) if `esample_default'
    assert _webal >= 0 if `esample_default'
    drop _webal

    ebalance treat x1 x2 x3 x4, targets(1) generate(ebw_verify)
    assert e(convg) == 1
    tempvar esample_named
    generate byte `esample_named' = e(sample)
    confirm variable ebw_verify
    assert !missing(ebw_verify) if `esample_named'
    assert ebw_verify >= 0 if `esample_named'
    restore
    estimates restore ipwra_atet
}
```

若只是独立社区示例、没有此前的主估计，则可省略最后的 `estimates restore ipwra_atet`；完整 selection 分析不得省略，否则后续主表可能不再归属于 IPWRA。最小二组语法为 `ebalance treat covarlist, targets(1)`；处理变量必须为 0/1 且两组存在。省略 `generate()` 时默认权重变量是 `_webal`；`generate(ebw_verify)` 指定新变量。`e(convg)==1` 表示收敛，`e(sample)` 标记适用样本。`preserve`/`restore` 防止社区命令生成对象污染主数据。

## 用户明确授权安装

仅在用户明确授权联网安装时执行 `ssc install ebalance`；verify 只探测已安装包，缺包输出 optional sentinel。

## 关键陷阱

- **陷阱**：默认 `_webal` 已存在。→ **触发**：再次运行可能替换默认变量。→ **Fix**：在 `preserve` 内运行或先处理旧变量；需要稳定名时用 `generate()`。→ **验证**：`confirm variable` 与 `e(sample)` 断言。
- **陷阱**：忽略 convergence。→ **触发**：权重对象存在但优化未收敛。→ **Fix**：必须断言 `e(convg)==1`。→ **验证**：非收敛不得报告结果。
- **陷阱**：把 moment balance 当识别证明。→ **触发**：平衡后声称无未观测混杂。→ **Fix**：只作 optional 敏感性诊断。→ **验证**：论文保留识别假设与外推限制。

## 边界 / 论文说明

说明 targets、有效 `e(sample)`、权重生成方式与 estimand。Entropy balancing 不能修复未观测混杂或支持域不足。
