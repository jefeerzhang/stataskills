---
name: stata-regression-ivreghdfe
description: ivreghdfe 参考：IV/2SLS/LIML/GMM2S + 多层固定效应（reghdfe + ivreg2 合体）。主文件见 stata-regression/SKILL.md。
---

# stata-regression-ivreghdfe

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「内生变量 + 多层 FE / 2SLS 吸收」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 10.6 IV / 2SLS + 多维固定效应：`ivreghdfe`（扩展，教材未覆盖）

`ivreghdfe`（Sergio Correia，2024）是 `ivreg2` + `reghdfe` 的合体：
把 `reghdfe` 的 `absorb()` 选项加到 `ivreg2`，让 IV/2SLS/GMM 也能吸收多层 FE。
工具变量或高级 SE + 多维 FE 同时需要时首选。

### 与 `reghdfe` 的分工
| 场景 | 用哪个 |
|---|---|
| OLS + 多层 FE | `reghdfe`（更快） |
| IV / 2SLS / LIML / GMM2S + 多层 FE | **`ivreghdfe`** |
| Driscoll-Kraay SE + 多层 FE | **`reghdfe`**（v6.13+，先 xtset；ivreghdfe 1.1.4 的 vce 不支持） |
| 两向聚类 + 多层 FE | `ivreghdfe` 或 `reghdfe` 都行 |

### 版本（2026-08 调研自 GitHub）
- **当前稳定版**：1.1.4 (29Nov2025)
- 协议：MIT (Copyright (c) 2024 Sergio Correia)
- 最新 commit：2026-07-02
- DOI: 10.5281/zenodo.82003805（Zenodo 自动归档每个 release）

### 安装（依赖 ftools + reghdfe + ivreg2 三件套）
```stata
* 1) ftools（必须先 compile，详见 10.5 节）
cap ado uninstall ftools
net install ftools, from("https://raw.githubusercontent.com/sergiocorreia/ftools/master/src/")
ftools, compile
mata: mata mlib index

* 2) reghdfe ≥ 6.0.2
cap ado uninstall reghdfe
net install reghdfe, from("https://raw.githubusercontent.com/sergiocorreia/reghdfe/master/src/")

* 3) ivreg2（核心包，Baum et al.）
cap ado uninstall ivreg2
ssc install ivreg2

* 4) ivreghdfe（最后装）
cap ado uninstall ivreghdfe
net install ivreghdfe, from("https://raw.githubusercontent.com/sergiocorreia/ivreghdfe/master/src/")
```
- 离线/防火墙：手工下 4 个 zip（ftools / reghdfe / ivreg2 / ivreghdfe）释放到本地，用 `net install, from(本地路径)`
- 查版本：`which ivreghdfe`

### 基本语法
```stata
* IV / 2SLS + 多维 FE
ivreghdfe depvar indepvars (endog = iv_vars), absorb(fe1 fe2 …)

* 两向聚类稳健 SE
ivreghdfe depvar indepvars (endog = iv), absorb(fe1 fe2) cluster(fe1 fe2)

* 注意：ivreghdfe 1.1.4 的 vce() 只支持 cluster / robust / unadjusted，
* 不支持 Driscoll-Kraay；需要 DK 时用上面的 reghdfe（v6.13+）

* 保存残差（必须 estimate 时加，不能事后 predict）
ivreghdfe depvar indepvars, absorb(fe1) resid(myresidname)

* LIML / GMM2S（ivreg2 原生估计方法都可用）
ivreghdfe depvar indepvars (endog = iv), absorb(fe1 fe2) liml
ivreghdfe depvar indepvars (endog = iv), absorb(fe1 fe2) gmm2s

* 配合 reghdfe 选项（tolerance / acceleration）
ivreghdfe depvar indepvars (endog = iv), absorb(fe1 fe2) tol(1e-6) accel(sd)
```

### 快速示例（auto.dta）
```stata
sysuse auto, clear
* 以 gear_ratio 当 length 的工具变量（语法演示；经济学上 gear→length 不严谨）
* 两层 FE + 两向聚类
ivreghdfe price weight (length = gear_ratio), absorb(turn trunk) cluster(turn trunk)
```
输出关键项：
- 工具变量第一阶段 F 检验（弱工具变量诊断）
- `HDFE` 标记（吸收 FE 后）
- IV/2SLS 标准误（不同于 OLS）

### 何时用 `ivreghdfe` 而非 `reghdfe`
- **内生变量**：需要 `ivreghdfe`（reghdfe 仅 OLS）
- **高级 SE**（Driscoll-Kraay）：用 `reghdfe`（v6.13+ 支持 `vce(dkraay #)`）；`ivreghdfe` 1.1.4 的 `vce()` 只支持 cluster / robust / unadjusted
- **CUE 估计**：`ivreg2` 才有，`ivreghdfe` **不支持** CUE
- **GMM / LIML**：`ivreghdfe` 通过 ivreg2 的 `gmm2s` / `liml` 选项
- 否则优先 `reghdfe`（更快；纯 OLS 没必要走 ivreghdfe）

### 已知 bug 与版本注意（GitHub README 抓取）
- **v1.1.4 (29Nov2025)** 修 bug #61：`resid()` + `cluster()` + 数据未按 cluster 排序 +
  未 `xtset` 时残差排序错。使用 `resid` 时**确保数据已 `sort clustervar` 或 `xtset`**。
- **v1.1.1 (14dec2021)** 加实验性 `margins` 后估计（仍实验性，可能边界问题）。
- **reghdfe v6 vs ivreg2 嵌套 cluster SE 微差异**：reghdfe 用 N-K-1 做 small sample 调整；
  ivreghdfe（用 ivreg2 的）用 N-K。二者都嵌套 cluster 时 SE 估计可能差一点点——选择看你想
  跟 `xtreg` 一致（ivreghdfe）还是内部一致（reghdfe）。

### Things to be aware of（来自官方 README）
- 启用 `absorb()` 后会自动激活 ivreg2 的 `small` / `noconstant` / `nopartialsmall` 选项
  （因为吸收大量 FE 后 small sample 调整必须开）
- ivreg2 部分高级 SE 选项（CUE）**不**被 ivreghdfe 支持——做 CUE + 多层 FE 无解
- reghdfe v6 的 `technique()` 选项（控制求解算法）可以传，但效果与 reghdfe 直接用略有差异
- 跑 OLS 时建议直接用 `reghdfe`——ivreghdfe 跑 OLS 比 reghdfe 慢约 2x（README 基准）

### 引用
```bibtex
@TechReport{Correia2024:ivreghdfe,
  Author = {Correia, Sergio},
  Title  = {ivreghdfe: reghdfe + ivreg2 (adds instrumental variable and additional
            robust SE estimators to reghdfe)},
  Year   = {2024}
}
```
> Sergio Correia, 2024. *ivreghdfe: Stata module for IV/2SLS with many levels of fixed
> effects.* Statistical Software Components, Boston College Department of Economics.
> GitHub: https://github.com/sergiocorreia/ivreghdfe

DOI: 10.5281/zenodo.82003805（Zenodo 自动归档每个 release）
