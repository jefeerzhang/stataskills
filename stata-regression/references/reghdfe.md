---
name: stata-regression-reghdfe
description: reghdfe 高维固定效应参考：多层 FE 的 OLS/IV、多向聚类、Driscoll-Kraay、compact 内存优化。主文件见 stata-regression/SKILL.md。
---

# stata-regression-reghdfe

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「2+ 层固定效应 / 多向聚类 / Driscoll-Kraay / 大 N 内存吃紧」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

## 10.5 高维固定效应：`reghdfe`（扩展，教材未覆盖）

`reghdfe`（**Noah Constantine & Sergio Correia**，里士满联储）是处理多维固定效应的
Stata 社区包，实现 Correia (2017) 的估计器。它是 `areg` / `xtreg` 的一般化。

### 版本（2026-08 调研自 GitHub）
- **SSC 当前稳定版**：`6.12.3 (20aug2023)`（注意不是某些文档说的 5.x）
- **最新开发版**：`6.13.1 (10Jan2026)`（GitHub `master` 分支；实验性 `vce(dkraay #)`）
- 旧版 5.x 与 6.x 并存：用 `version(5)` 切回 5.x 行为

### 安装（必须先 compile ftools）
```stata
* ===== 推荐：6.x 开发版（含最新改进）=====
* 0) 新版依赖管理器
ssc install require, replace
* 1) 装 ftools（首次或更新都要走一遍）
cap ado uninstall ftools
net install ftools, from("https://raw.githubusercontent.com/sergiocorreia/ftools/master/src/")

* ⚠️ 必须 compile ftools——否则报错 "class FixedEffects undefined"
ftools, compile
mata: mata mlib index

* 2) 装 reghdfe 6.x
cap ado uninstall reghdfe
net install reghdfe, from("https://raw.githubusercontent.com/sergiocorreia/reghdfe/master/src/")

* 3) 如需 IV / GMM，再装 ivreg2 + ivreghdfe
cap ado uninstall ivreg2hdfe           * 老包名清理
cap ado uninstall ivreghdfe
cap ssc install ivreg2                  * IV 核心包（Baum et al.）
net install ivreghdfe, from("https://raw.githubusercontent.com/sergiocorreia/ivreghdfe/master/src/")

* ===== 备选：5.x 稳定版（不能访问 GitHub master 时）=====
ssc install reghdfe
```
- **配套依赖**：`ftools`（高级 Mata，**必须 compile**）；`parallel`（仅当用 `parallel()` 选项）
- **离线/防火墙**：手工下 `ftools/reghdfe/ivreghdfe` 三个 zip 释放到本地，用 `net install, from(本地路径)`
- **查版本**：`which reghdfe`（首行注释含版本号，如 `*! version 6.13.1 10Jan2026`）

### Things to be aware of（来自官方 README）
- 依赖 `ftools`（Stata 12 及更老还需 `boottest`，现已罕用）
- IV / GMM 不直接通过 reghdfe，而是通过 `ivreg2` + `absorb()` 选项（即 `ivreghdfe` 包）
- 与 reghdfe 联动的命令（`regife` / `poi2hdfe` / `ppml_panel_sg` / `ppmlhdfe` 等）需确认兼容版本
- `cache` 与 `groupvar` 选项尚未完全支持（GitHub TODO 仍在）
- 旧版兼容：`version(3)` / `version(5)` 切回 v3.x 或 v5.x 行为

### 版本演进时间线（GitHub README 抓取）
| 版本 | 日期 | 关键变化 |
|---|---|---|
| v4.1 | 2017-02-28 | 整个改写为 Mata，配 ftools 加速 3 – 10x |
| v5.0 | 2018-06-29 | 加 `basevar` + `margins` 后估计 + 报告 `_cons` |
| v5.6 | 2019-01-26 | 数值精度改进（不解标准化再解）；首次调用 +2s 提速 |
| v5.6.8 | 2019-03-03 | 同期发布 `ppmlhdfe`（Poisson + FE） |
| v6.12.0 | 2021-06-26 | 加 `indiv()` / `group()` / `aggregation()` 个体 FE |
| v6.13.1 | 2026-01-10 | 加实验性 `vce(dkraay #)` Driscoll-Kraay SE |

### 何时用 `reghdfe` 而非 `regress` / `areg` / `xtreg`
- 回归里有 2 个及以上固定效应层（如「州 × 年」双向 FE）
- 固定效应数量多（如几千个企业 × 几十个年份）
- 需要在 IV / GMM 框架下吸收 FE
- 需要多向聚类稳健 SE（两向及以上）
- 需要 Driscoll-Kraay SE（面板数据跨相关+自相关稳健）
- 即使单层 FE，`reghdfe` 也比 `areg` / `xtreg` 更快

### 基本语法
```stata
* OLS + 多个 FE（替代 areg）
reghdfe depvar indepvars, absorb(fe1 fe2 …)

* IV / GMM（ivregress / ivreg2 语法皆可）
reghdfe depvar indepvars (endog = iv_vars), absorb(fe1 fe2 …)

* 聚类稳健 SE（单/两/多向）
reghdfe depvar indepvars, absorb(fe1 fe2) vce(cluster clustervar)
reghdfe depvar indepvars, absorb(fe1 fe2) vce(cluster fe1 fe2)    // 两向聚类

* Driscoll-Kraay SE（v6.13+，面板数据；数字 = 滞后期数）
* 前提：先 xtset panelvar timevar（或 tsset），否则报 r(9)
xtset panelvar timevar
reghdfe depvar indepvars, absorb(panelvar timevar) vce(dkraay 2)

* 固定斜率（per-group slope）：用因子变量交互，不是 feslope() 选项
reghdfe depvar i.fe1##c.indepvar, absorb(fe1)                    // fe1 内 indepvar 的斜率不同

* 个体固定效应（Constantine & Correia 2021；区别于固定斜率）
reghdfe depvar indepvars, absorb(fe1) individual(firm) group(occ) aggregation(sum)

* 内存优化（大 N 救命，5 – 10x 节省）
reghdfe depvar indepvars, absorb(fe1 fe2) compact poolsize(1000)
```

### 高级选项速查
| 选项 | 用途 | 何时用 |
|---|---|---|
| `absorb(fe1 fe2 …)` | 多维 FE | 始终需要 |
| `vce(cluster ...)` | 聚类稳健 SE | 始终推荐（比 robust 更准） |
| `vce(dkraay #)` | Driscoll-Kraay SE（v6.13+，需 xtset/tsset） | 面板数据跨相关+自相关 |
| `vce(robust)` | 异方差稳健 SE | 简单场景 |
| `i.fe##c.var`（因子交互） | fe 内 var 的斜率不同 | 固定斜率模型 |
| `individual() group() aggregation()` | 个体 FE | Constantine & Correia 2021 |
| `compact` + `poolsize(#)` | 内存优化 | 大 N + 内存吃紧 |
| `version(3)` / `version(5)` | 旧版行为 | 兼容性 |
| `residuals(varname)` | 保存残差 | 必须 estimate 时加，不能事后 `predict, resid` |
| ⚠️ `cache` | 复用变换 | **尚未完全支持**（GitHub TODO 仍在） |

### `vce(dkraay)` 示例（v6.13+，面板数据）
```stata
* Driscoll-Kraay 标准误：面板数据跨相关 + 自相关稳健
* 数字是滞后阶数（按面板 T 期长度与自相关跨度选）。
* 必须先 xtset（或 tsset），否则报 r(9)；auto.dta 是横截面不能直接做。
use longitudinal_mixed, clear
clonevar drink0 = drink98
clonevar drink2 = drink00
clonevar drink4 = drink02
clonevar drink6 = drink04
clonevar drink8 = drink06
clonevar drink10 = drink08
drop drink98 drink00 drink02 drink04 drink06 drink08
reshape long drink, i(id) j(wave)
xtset id wave
reghdfe drink c.wave, absorb(id) vce(dkraay 2)
```
- 何时用：面板数据 T 期较长、个体间可能跨相关（如某国 shock 影响所有国）
- Driscoll-Kraay 比 `vce(cluster panelvar)` 更稳健，因为它对跨个体相关也调整

### `compact` 内存优化示例
```stata
sysuse auto, clear
* compact + poolsize 分块处理：大 N 时省 5 – 10x 内存
reghdfe price weight length, absorb(foreign rep78) compact poolsize(1000)
```
- 何时用：数据规模超内存（如几亿 obs + 多 FE），或机器内存吃紧
- 代价：速度略降（约 10-20%）

### 快速示例（auto.dta）
```stata
sysuse auto, clear
* 两层 FE（turn + trunk）+ 聚类到 turn
reghdfe price weight length, absorb(turn trunk) vce(cluster turn)
```
输出关键项：
- `HDFE Linear regression`（区别于 `regress` 的 `OLS`）
- `Number of obs`（吸收单点组后）
- `Absorbing N HDFE groups`（被吸收的 FE 组数）
- `Within R-sq.`（组内 R²，对组间变异被吸收更可信）
- `Absorbed degrees of freedom`（被吸收 FE 的 DoF 与冗余数）

### 与 `regress i.fe`（因子变量记法）的选择
| 维度 | `reghdfe` | `regress i.fe`（因子变量） |
|---|---|---|
| FE 数量上限 | 上万（用迭代求解） | 受 Stata 矩阵维度限制（Stata/MP 11 万） |
| 多层 FE | ✅ 天然支持（多个变量） | 需手动 `i.fe1##i.fe2`（笛卡尔积爆炸） |
| 固定斜率 | ✅ `i.fe##c.var`（因子交互） | ❌（需手工 demean） |
| 单点组处理 | 自动迭代剔除 | 不处理，会吃掉 DoF |
| 输出 | HDFE 标记 + Within R² + 吸收表 | 标准 OLS |

### 关键 FAQ（来自 scorreia.com/software/reghdfe）
- **「fixed effect nested within cluster」自动检测**：当 `vce(cluster)` 的变量是 `absorb()`
  变量的粗化（如 state–clustered SE + county–level FE），reghdfe 在 DoF 计算中**不再双罚**，
  不把 county 算进被吸收 DoF。输出会标注 `* fixed effect nested within cluster; treated
  as redundant for DoF computation`。可用 `dof(none)` / `dof(full)` 关闭。
- **四个 R²**：报告 `R-sq.`（总）、`Adj R-sq.`（调整总）、`Within R-sq.`（组内，最常报告）。
  Within R-sq. = 1 − SSR_within / SST_within，剔除 FE 后的解释力。
- **内存不够**：`compact` 选项让数据更省内存（5 – 10x）；配合 `poolsize(#)` 分块处理。极端情况用 `keep()` 子样本回归。
- **跟 `esttab` / `estout` 组合**：`reghdfe` 兼容（`est sto` + `esttab` 直接用）。
- **观测数随 FE 变化**：reghdfe 处理不了每个 obs FE 数不同时的情况，需先 `egen group = group(...)`。

### 何时不用 reghdfe
- 只有 1 层 FE 且数量少（< 100）→ `regress i.fe` 或 `areg` 足够
- 因变量是 0/1 → 用 `xtlogit` / `logit i.fe`（reghdfe 是线性 IV/OLS/GMM）
- 没有 Stata 网络（reghdfe 需 `ssc install` 联网；离线需手工装）

### 引用
```bibtex
@TechReport{Correia2017:HDFE,
  Author = {Correia, Sergio},
  Title  = {Linear Models with High-Dimensional Fixed Effects:
            An Efficient and Feasible Estimator},
  Note   = {Working Paper},
  Year   = {2017}
}
```
> Noah Constantine, Sergio Correia, 2021. *reghdfe: Stata module for linear and
> instrumental-variable/GMM regression absorbing multiple levels of fixed effects.*
> Statistical Software Components S457874, Boston College Department of Economics.
> RePEc 引用：https://ideas.repec.org/c/boc/bocode/s457874.html

DOI: 10.5281/zenodo.27755549（Zenodo 自动归档每个 release）

论文 PDF：http://scorreia.com/research/hdfe.pdf
