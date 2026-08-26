---
name: stata-selection-psmatch2
description: Optional 社区 psmatch2 参考；当用户明确需要旧代码兼容性或 matching 敏感性分析时加载。
---

# Optional 社区包 `psmatch2`

## 何时用

仅在复现已有论文/旧 do-file，或用户明确要求社区匹配实现时使用。它不是默认主估计，也不优于官方 `teffects ipwra`。

## 默认探测与最小代码

```stata
version 19.5
capture which psmatch2
if _rc {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__"
}
else {
    preserve
    psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate
    return list
    describe
    restore
}
```

本机已核实 `psmatch2.ado` v4.0.12（2016-01-30）：syntax 包含 `ATE`，**不包含 `ATT` option**。默认不写 `ate` 时估计 treated-effect/ATT 语义；写 `ate` 才切换到 ATE 输出。selection 主 estimand ATET 与社区默认 ATT 只作术语对齐，两者不是同一实现。

## 用户明确授权安装

只有用户明确授权联网安装时才执行：

```stata
ssc install psmatch2
which psmatch2
```

verify 只探测已安装包，不安装；缺包输出 optional sentinel。

## 标准误、权重与匹配样本

`psmatch2` 的 analytical standard errors 依赖具体 matching method 与额外假设；propensity score 本身为估计量带来的不确定性并非所有路径都被完整传播。论文须说明采用的标准误实现，并把社区结果作为敏感性/兼容性对照。

本机 v4.0.12 source 会创建匹配相关对象，但跨版本文档**不锁定**返回 scalar 或生成变量名。verify 必须先检查本机 help/source，再从实际 `return list`、`describe` 核实非缺失效应结果以及权重或匹配样本对象；不能先验硬编码未经当前版本核实的名称。

## 关键陷阱

- **陷阱**：使用不存在的 `att` option。→ **触发**：v4.0.12 syntax 没有该 option。→ **Fix**：默认命令即 treated-effect/ATT 语义；ATE 才加 `ate`。→ **验证**：查看 `psmatch2.ado` 的 `syntax` 与本机 smoke log。
- **陷阱**：包未安装仍当作内置命令。→ **触发**：`which psmatch2` 非零。→ **Fix**：输出 sentinel；只有用户授权才安装。→ **验证**：缺包路径不执行估计。
- **陷阱**：锁死返回名或生成对象。→ **触发**：版本变化导致旧断言失败。→ **Fix**：先核实当前 help/source 与实际 `return list`/`describe`。→ **验证**：verify 对当前版本的实际对象做非缺失检查。

## 边界 / 论文说明

报告 estimand（默认 ATT 或 `ate` 的 ATE）、neighbor、caliper/radius（如使用）、replacement、共同支持、匹配样本与标准误限制。数值差异不能被解释为社区实现普遍更正确。
