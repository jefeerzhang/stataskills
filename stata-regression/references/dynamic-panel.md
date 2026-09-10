---
name: stata-regression-dynamic-panel
description: 动态面板估计：Arellano-Bond difference GMM、Blundell-Bond system GMM、xtdpd，以及 GitHub 社区包 xtabond2 / xtdpdgmm 的可审计工作流。
---

# 动态面板模型

## 1. 先判断是否真的是动态面板

模型包含滞后因变量：

```stata
version 19.5
xtset id t
xtabond y x1 x2, lags(1) vce(robust)
```

固定效应下 `L.y` 与变换后的误差相关，不能把 `xtreg, fe` 当作无偏动态面板估计。短 T、较多横截面单位是 GMM 的典型使用场景；T 较大时优先考虑 bias-corrected FE 或直接报告 FE 与 GMM 的敏感性对照。

## 2. 内置 Stata 路径

### Difference GMM：Arellano-Bond

```stata
xtset id t
xtabond y x1 x2, lags(1) twostep vce(robust)
estat abond                 // AR(1) 通常显著，AR(2) 不应显著
estat sargan                // 仅在 iid 假设下解释；robust 时谨慎
```

### System GMM：Arellano-Bover / Blundell-Bond

```stata
xtdpdsys y x1 x2, lags(1) twostep vce(robust)
estat abond
estat sargan
```

系统 GMM 额外使用水平方程，必须说明额外的初始条件/平稳性假设；不能因为效率更高就默认替代 difference GMM。

### 更细的矩条件控制

```stata
xtdpd y L.y x1 x2, dgmmiv(y, lagrange(2 4)) iv(x1 x2) twostep vce(robust)
estat abond
```

`lagrange(2 4)` 限制滞后工具窗口，实际分析应按 T 和理论外生性缩窄窗口。

## 3. GitHub 社区实现

两个常用项目是 Roodman 的 [`xtabond2`](https://github.com/droodman/xtabond2) 和 Kripfganz 的 [`xtdpdgmm`](https://github.com/kripganz/xtdpdgmm)。它们提供更明确的 `gmm()` / `iv()` 工具分类、collapse、forward orthogonal deviations、Windmeijer 修正与 Difference-in-Hansen 分块检验。

```stata
* 社区包：按项目 README 安装；CI 默认只做可选包探测
ssc install xtabond2, replace
net install xtdpdgmm, from("https://kripfganz.de/stata/xtdpdgmm/") replace

xtabond2 y L.y x1 x2, gmmstyle(L.y, laglimits(2 4) collapse) ///
    ivstyle(x1 x2) twostep robust small

xtdpdgmm y L.y x1 x2, model(diff) gmmiv(L.y, lag(2 4) collapse) ///
    iv(x1 x2) twostep vce(robust)
estat abond
estat overid
```

不同版本的 `xtdpdgmm` 选项名可能有细微差异，运行前以 `help xtdpdgmm` 和仓库 README 为准；不要把未经本机验证的社区命令写成内置语法。

## 4. 必报检验与解释

每次估计至少记录：AR(1)/AR(2)（差分残差）、Sargan 或 Hansen J、工具数与 groups 数、system GMM 的 Difference-in-Hansen 分块检验，以及 difference/system 和窄/宽滞后窗口的敏感性对照。AR(1) 显著通常是差分造成的；AR(2) 不显著才支持常见矩条件。robust 或 two-step 时优先报告 Hansen；工具数接近或超过 groups 时，用 `collapse`、缩窄 `laglimits()` 或减少 IV-style 工具。Hansen p 值接近 1 也可能是工具过多导致检验无力，不能当作外生性证明。two-step robust 应使用 Windmeijer 修正标准误并报告 `small` 与 VCE 设置。

## 5. 陷阱四件套

1. **工具变量爆炸** → 工具数接近或超过组数 → `collapse` + `lag(2 3)` 缩窗 → 输出中明确报告 groups 与 instruments。
2. **把 AR(1) 显著当失败** → 一阶差分机械产生一阶相关 → 检查 AR(2) → AR(2) 不显著才支持无二阶序列相关。
3. **无理由使用 system GMM** → 水平矩条件缺少平稳性论证 → 先跑 difference GMM 并写出初始条件 → 再以 system 作为有理由的敏感性分析。
4. **把 Hansen p 值当识别证明** → 工具过多时检验失去功效 → 控制工具数并结合制度/时序论证 → 报告检验局限。
5. **只报总体 Hansen** → 某一组 GMM 或 level moment 可能单独失效 → 用独立 `gmmstyle()`/`ivstyle()` 分组并检查 Difference-in-Hansen → 在表注报告分块检验。

## 6. 踢走规则

- 政策处理时点、事件研究或错时处理 → `stata-did` / `stata-did-community`。
- 只需要静态个体固定效应 → `xtreg, fe` 或 `reghdfe`，不要为了“面板”自动上 GMM。
- T 很大或 N 很小 → 先评估 Nickell bias、有限样本和 GMM 工具有效性，不直接套模板。
