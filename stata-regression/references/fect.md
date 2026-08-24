---
name: stata-regression-fect
description: fect 面板因果推断参考：错时 DID 的 TWFE 偏差修正（交互固定效应 IFE / 矩阵补全 MC）。主文件见 stata-regression/SKILL.md。
---

# stata-regression-fect

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「错时 DID 的 TWFE 偏差修正」时加载本文件。注意：fect 是 DID 主题，通常先转到 `stata-did` / `stata-did-community`。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 10.7 面板因果推断：`fect`（扩展，教材未覆盖）

`fect`（Licheng Liu, Ye Wang, Yiqing Xu, Ziyi Liu）是 **TWFE 偏差修正工具**。
它用 reghdfe 作引擎，专门解决 **staggered adoption DiD** 下经典双向 FE 估计 ATT 的**负权重偏误**。

### 解决的特定问题（vs reghdfe / ivreghdfe）

| 工具 | 解决的问题 |
|---|---|
| `reghdfe`（10.5 节）| **回归系数估计**——多维 FE 的 OLS / IV |
| `ivreghdfe`（10.6 节）| **内生性修正**——IV/2SLS + 多 FE |
| **`fect`（10.7 节）** | **因果识别修正**——staggered DiD 下 TWFE 估计 ATT **有偏**的修正 |

**经典 TWFE 在 staggered adoption 下有什么问题？**

- Goodman-Bacon (2021)：当处理不是同时发生（不同时点不同单位开始处理），
  ATT 估计是**多组 2×2 DiD 的加权平均**，权重的**符号**可正可负（"negative weighting"），
  导致**符号反转**或严重偏误
- de Chaisemartin & D'Haultfœuille (2020)：类似结论，TWFE 估计可能与真实 ATT 反号
- 实证例子：yiqingxu.org 网站 / 多个 replication studies 都展示了经典 TWFE 偏差

**fect 的对策**：
- **`method(ife)`**（交互固定效应 / interactive fixed effects，Bai 2009）——显式建模处理×时间交互异质性
- **`method(mc)`**（矩阵补全 / matrix completion，Athey et al. 2021）——把未观测反事实当矩阵补全问题解
- **`method(both)`**——同时跑 IFE 和 MC，按 CV 选更优

### 安装（依赖 reghdfe + ftools + _gwtmean）
```stata
* 三个依赖（部分已装过）
cap ado uninstall reghdfe
ssc install reghdfe, replace
cap ado uninstall _gwtmean
ssc install _gwtmean, replace
* ftools 应该已装（reghdfe 装过）
cap which ftools
display "ftools rc=" _rc

* 主包
cap ado uninstall fect
net install fect, all replace from("https://raw.githubusercontent.com/xuyiqing/fect_stata/master/")
```
- Stata 14+
- 配套数据 `simdata1.dta`（7,000 obs × 100 处理 + 100 控制 × 35 时段，staggered adoption），
  装包时复制到当前目录

### 基本语法
```stata
* Y 是被解释变量（varlist 限 1 个）
* D 在 treat() 选项（不是 varlist 第二个！）
fect Y, treat(D) unit(id) time(t) [method(ife|mc|both)] [se] [cov(X1 X2)] [placeboTest]

* 例：双向 FE（基线，含 TWFE 偏差）
fect Y, treat(D) unit(id) time(t) se

* 例：交互固定效应（修正 TWFE 偏差）
fect Y, treat(D) unit(id) time(t) method(ife) se

* 例：矩阵补全（最新 ML 方法）
fect Y, treat(D) unit(id) time(t) method(mc) se

* 例：加 placebo 检验（验证 ATT 是否真的非零）
fect Y, treat(D) unit(id) time(t) method(ife) placeboTest se

* 例：导出 PNG（输出 ATT 时序图）
fect Y, treat(D) unit(id) time(t) method(ife) ///
    saving("/path/to/output")
graph export "/path/to/output.png", replace
```

### simdata1 演示（100 处理 + 100 控制 + 35 时段）
```stata
cd "your_path_to/demo"
use simdata1, clear

* 经典 TWFE（含负权重偏误风险）
fect Y, treat(D) unit(id) time(t) se

* IFE：修正后
fect Y, treat(D) unit(id) time(t) method(ife) se

* MC：另一种修正
fect Y, treat(D) unit(id) time(t) method(mc) se
```
输出关键项：
- **ATT（平均处理效应）**——`r(att)` 或直接显示
- **每期 ATT**（动态效应）——可在图形上看
- **Placebo 测试 P 值**——验证 ATT 非零的统计显著性
- **goodness-of-fit 指标**——选 FE / IFE / MC 的依据

### 何时用 `fect`（vs reghdfe）
- **staggered DiD 场景**——处理时点不统一时**必用** fect（否则 TWFE 估计有偏）
- **传统 2 期 DiD（同时处理）**——经典 TWFE OK，无需 fect
- **回归系数本身**（如协变量对 Y 的影响）——用 reghdfe 即可，fect 只关心 ATT
- **面板 IV**——用 ivreghdfe；fect 不做 IV

### 已知陷阱
- **处理变量必须 0/1**——`treat()` 必须只含 0/1，否则报"treat invalid"
- **MC 在小样本下不稳定**——`method(mc)` 需要较大样本（N*T > 几千）
- **placeboTest 慢**——bootstrap 默认 200 次，单跑要 1-2 分钟
- **`vartype()` 选项**：默认 parametric bootstrap；`vartype(jackknife)` / `vartype(wild)` 可换
- **数据必须是面板长格式**（每行一个 (unit, time)）；宽表先 reshape long
- **强依赖 reghdfe**：reghdfe 没装/版本过旧 → fect 直接 r(111) 拒跑

### 与 `csdid` / `did_imputation` 的对比（不整合，仅供选型）
- **csdid**（R. W. Taylor）：同样修正 TWFE 偏差，方法不同（重复 2×2 DiD + 简单加权）
- **did_imputation**（Borusyak, Jaravel, Spiess）：矩阵补全的另一实现，与 fect MC 类似
- **eventstudyinteract**（Sun & Abraham 2021）：用交互固定效应修正 TWFE
- 选择：数据集小 → csdid；大 + 想要因果 ML → fect/mc；想要学术稳健 → Sun-Abraham / eventstudyinteract

### 引用
> Licheng Liu, Ye Wang, Yiqing Xu, Ziyi Liu. (2020). *A Practical Guide to Counterfactual
> Estimators for Causal Inference with Time-Series Cross-Sectional Data.* SSRN 3555463.
> https://papers.ssrn.com/abstract=3555463

GitHub: https://github.com/xuyiqing/fect_stata
