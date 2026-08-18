---
name: stata-did-community
description: 帮助用户用 Stata 社区包做双重差分分析。Use when needing reghdfe 事件研究 / eventdd csdid eventstudyinteract 错时 DID 替代命令 / Callaway-Sant'Anna 估计量 / csdid notyet never method(dr ipw reg) / Wooldridge ETWFE / jwdid poisson logit hettype(twfe event cohort time) / BJS 插补法 / did_imputation leaveout autosample pretrends unitcontrols / 合成控制 synth / synth_runner placebo 置换推断 / 合成DID sdid / 少数处理单元 donor pool / synthetic control / synthetic difference-in-differences / 方法选择决策树。全部需 ssc install。内置 DID 命令（didregress / xtdidregress / hdidregress / xthdidregress）见 stata-did skill。
---

# Stata 双重差分：社区包（reghdfe / csdid / jwdid / did_imputation / synth / sdid）

本 skill 覆盖主流 DID 社区包，需 `ssc install`。Stata 内置 DID 命令（`didregress` / `xtdidregress` / `hdidregress` / `xthdidregress`）见 `stata-did` skill。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 命令选择表（社区包）

| 数据结构 | 处理时点 | 推荐命令 | 说明 |
|---|---|---|---|
| 面板（长前期） | 单时点，处理单位极少（1 至几个） | `synth` / `sdid` | 合成控制 / 合成 DID |
| 面板/重复截面 | 错时（staggered） | `csdid` | Callaway-Sant'Anna 估计量；DR/IPW/Reg 三方法；见第 1 节 |
| 面板/重复截面 | 错时（staggered） | `jwdid` | Wooldridge ETWFE；回归法框架；支持 poisson/logit 非线性；见第 1 节 |
| 面板/重复截面 | 错时（staggered） | `did_imputation` | BJS 插补法；`leaveout` 方差修正（唯一实现）；见第 1 节 |

---

## 1. 错时事件研究的替代命令：`eventdd` / `csdid` / `eventstudyinteract`

Stata 内置的 `hdidregress` 不是唯一选择；社区有三个主流替代：

| 命令 | 包 / 论文 | 优势 | 何时用 |
|---|---|---|---|
| `eventdd` | SSC：`ssc install eventdd` | 一行 `eventdd y i.year, timevar(rel_time) method(fe, cluster(id)) graph_op(...)` 出图；最简单 | 探索阶段、要快速看图时 |
| `csdid` | SSC：`ssc install csdid` | Callaway & Sant'Anna (2021) 估计量；双重稳健；可控制协变量；与 `hdidregress aipw` 同源思路 | 想做更严谨的异质性处理效应估计 |
| `eventstudyinteract` | SSC：`ssc install eventstudyinteract` | Sun & Abraham (2021) 异质性修正；估计"干净"事件研究系数，避免错时下 TWFE 偏误 | 想发顶刊 / 需要与传统 TWFE 估计对照时 |

**这三者都不是 Stata 内置**——需 `ssc install`；网络受限时（如中国大陆）安装可能失败，请改回 `hdidregress`。

### csdid 详解：Callaway-Sant'Anna 估计量

`csdid` 是 Callaway & Sant'Anna (2021) 异质性稳健 DID 估计量的 Stata 实现（Rios-Avila & Sant'Anna，SSC），与 `hdidregress aipw` 同源理论，但提供更多选项：三种估计方法（reg/dr/ipw）、两种控制组（notyet/never）、wild bootstrap 推断、以及更细粒度的事后聚合。

#### 安装

```stata
ssc install drdid, replace             // csdid 的依赖包（Doubly Robust DID）
ssc install csdid, replace             // 主包
```

`drdid` 是 `csdid` 的底层引擎——不装 `drdid` 直接跑 `csdid` 会报 `command not found`。

#### 核心语法

```stata
csdid y [xvars], ivar(id) time(t) gvar(first_treat) ///
    [notyet | never] [method(reg | dr | ipw)] ///
    [wboot [reps(#)] [seed(#)]] [cluster(var)]
```

| 选项 | 含义 | 默认 |
|---|---|---|
| `ivar(id)` | 面板单位 id | —（重复截面省略） |
| `time(t)` | 时间变量 | 必填 |
| `gvar(first_treat)` | 首次处理期（0 或 `.` = 从未处理） | 必填 |
| `notyet` | 用**尚未处理**的单位做对照 | 推荐，与 `hdidregress` 一致 |
| `never` | 只用**从未处理**的单位做对照 | 有 never-treated 时可用 |
| `method(reg)` | 回归法 | 无协变量时三法等价 |
| `method(dr)` | 双重稳健（推荐，有协变量时） | — |
| `method(ipw)` | 逆概率加权 | — |
| `xvar(varlist)` | 协变量（仅 dr/ipw 有效；reg 忽略） | — |
| `wboot` | wild bootstrap 推断 | 默认渐近 SE |
| `reps(#)` | bootstrap 重抽次数 | 999 |
| `seed(#)` | 随机种子 | — |
| `cluster(var)` | 聚类变量 | 不加则不聚类 |

#### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install drdid, replace
ssc install csdid, replace

* 1. 数据准备
* 使用 mpdta 数据（Municipal Panel Data for DiD Analysis）
* first_treat = 首次处理年份；0 = 从未处理
use mpdta, clear
xtset countyreal year

* 2. 基本估计：notyet 控制组 + 回归法
csdid lemp, ivar(countyreal) time(year) gvar(first_treat) notyet method(reg)

* 3. 事后聚合
estat simple                           // 总体简单聚合 ATT
estat group                            // 按 cohort（首次处理年份）聚合
estat event                            // 按事件时间（相对处理期）聚合

* 4. 事件研究图（estat event 后手动画）
estat event
* csdid 不直接出图；需从 e(b)/e(V) 提取系数后 coefplot
* 简便做法：用 estat event 的结果矩阵
matrix event_b = r(table)
* 或用 csdid_stats（配套包）自动出图：
* ssc install csdid_stats, replace
* csdid_stats event, graph

* 5. 双重稳健法（有协变量时推荐）
csdid lemp lpop, ivar(countyreal) time(year) gvar(first_treat) ///
    notyet method(dr)
estat simple
estat event

* 6. wild bootstrap 推断（聚类数 < 50 时推荐）
csdid lemp, ivar(countyreal) time(year) gvar(first_treat) ///
    notyet method(reg) wboot reps(999) seed(20260817)
```

#### `gvar()` 编码要点

- `gvar(first_treat)` 必须是**数值型**，每个单位一个值：首次处理期的年份。
- **从未处理的单位**：编码为 `0` 或 `.`（缺失）——`csdid` 内部用 `gvar==0` 或 `missing(gvar)` 识别 never-treated。
- 不要用 `9999` 等哨兵值——`csdid` 会把它当作"在 9999 年接受处理"，结果完全错误。

```stata
* 正确编码
replace first_treat = 0 if never_treated     // 或
replace first_treat = . if never_treated

* 错误编码（csdid 会误识别）
replace first_treat = 9999 if never_treated   // ← 错！
```

#### `notyet` vs `never`：控制组选择

| 选项 | 控制组 | 优点 | 缺点 |
|---|---|---|---|
| `notyet`（推荐） | 尚未处理的单位 + 从未处理的单位 | 样本量大，统计效率高 | 依赖无预期假设（no anticipation） |
| `never` | 只用从未处理的单位 | 不依赖无预期假设 | 样本量可能小，SE 更大 |

**何时用 `never`**：怀疑"即将处理"的单位在处理前已改变行为（违反无预期假设）。
**默认用 `notyet`**：与 `hdidregress` 默认行为一致，大多数研究场景适用。

#### csdid vs hdidregress aipw

| 维度 | `csdid` | `hdidregress aipw` |
|---|---|---|
| 理论基础 | Callaway & Sant'Anna (2021) | 同 |
| 包来源 | SSC 社区包 | Stata 18+ 内置 |
| 估计方法 | reg / dr / ipw（显式选择） | aipw（隐式 DR） |
| 控制组 | notyet / never（显式选择） | notyet（默认） |
| 推断 | 渐近 SE / wild bootstrap | 渐近 SE / wild bootstrap |
| 事后聚合 | `estat simple/group/event` | `estat aggregation, overall/cohort/dynamic` |
| 无协变量时 | 三法数值一致 | 与 csdid method(reg) 一致 |
| 有协变量时 | `method(dr)` 对应 aipw | aipw |
| 稳健性对照 | 推荐与 `hdidregress aipw` 互为对照 | 推荐与 `csdid` 互为对照 |

**结论**：两者同源、结果一致；`csdid` 更灵活（可选控制组与方法），`hdidregress` 更方便（官方 estat 诊断体系）。**论文中建议两者都跑，报告一致性**。

#### 与 diff-diff 的对应关系

`csdid` ≈ diff-diff 的 `CallawaySantAnna`（Python 估计量）。diff-diff 用 `csdid` 作为 Stata 端的交叉验证锚点，确认 Python 实现与 Stata 参考一致（精度 ~1e-6）。

### jwdid 详解：Wooldridge ETWFE 估计量

`jwdid` 是 Fernando Rios-Avila 基于 Wooldridge (2021, 2023) 实现的 **ETWFE（Extended Two-Way Fixed Effects）** 估计量（SSC）。核心思路：用**饱和交互模型**（cohort × time 全交互 + 固定效应）替代传统 TWFE，避免错时 DID 下的负权重偏误。与 `csdid` 的"逐组×逐期分别估计后聚合"不同，`jwdid` 是**单次回归**出全部 ATT(g,t)。

#### 安装

```stata
ssc install hdfe, replace             // jwdid 的依赖包
ssc install jwdid, replace            // 主包
```

`hdfe` 是 `jwdid` 的底层引擎——不装 `hdfe` 直接跑 `jwdid` 会报 `hdfe not found`。

#### 核心语法

```stata
jwdid y [xvars], ivar(id) tvar(t) gvar(first_treat) ///
    [never] [group] [method(poisson | logit | ppmlhdfe)] ///
    [hettype(full | time | cohort | event | twfe)] ///
    [cluster(var)] [anticipation(#)]
```

| 选项 | 含义 | 默认 |
|---|---|---|
| `ivar(id)` | 面板单位 id | —（省略则假设重复截面） |
| `tvar(t)` | 时间变量 | 必填 |
| `gvar(first_treat)` | 首次处理期（0 或 `.` = 从未处理） | 必填 |
| `never` | 只用从未处理的单位做对照 | 默认用 notyet + never |
| `group` | 用组固定效应替代个体固定效应 | 线性模型默认个体 FE |
| `method()` | 非线性估计方法 | 默认 `reghdfe`（线性） |
| `hettype()` | 异质性约束 | 默认 `full`（完整 cohort × time） |
| `cluster(var)` | 聚类变量 | 面板默认按 `ivar()` 聚类 |
| `anticipation(#)` | 预期期数（处理前几期开始算处理） | 1（即 g-1 为参考期） |

#### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install hdfe, replace
ssc install jwdid, replace

* 1. 数据准备
frause mpdta.dta, clear              // 或 use mpdta.dta
xtset countyreal year

* 2. 基本估计：默认 notyet + never 控制组
jwdid lemp, ivar(countyreal) tvar(year) gvar(first_treat)

* 3. 事后聚合
estat simple                         // 总体简单聚合 ATT
estat group                          // 按 cohort（首次处理年份）聚合
estat calendar                       // 按时间聚合（每年总体 ATT）
estat event                          // 按事件时间聚合（事件研究）

* 4. 事件研究图
estat event
estat plot                           // 一键出图

* 5. 平行趋势检验
estat event, pretrend                // 检验 pre-treatment ATT 是否联合为零

* 6. 仅用 never-treated 做对照
jwdid lemp, ivar(countyreal) tvar(year) gvar(first_treat) never
estat simple
estat event

* 7. 有协变量的估计
jwdid lemp lpop, ivar(countyreal) tvar(year) gvar(first_treat)

* 8. 非线性模型：poisson（计数数据）
gen emp = exp(lemp)
jwdid emp lpop, ivar(countyreal) tvar(year) gvar(first_treat) ///
    method(poisson) group
estat simple                         // 非线性模型的 ATT（边际效应）
estat event

* 9. 异质性约束：只允许事件时间异质性
jwdid lemp, ivar(countyreal) tvar(year) gvar(first_treat) ///
    never hettype(event)
estat event
```

#### hettype() 异质性约束详解

| 选项 | 含义 | 何时用 |
|---|---|---|
| `full`（默认） | 完整 cohort × time 异质性 | 标准错时 DID |
| `time` | 只允许时间异质性（所有 cohort 同一时间效应） | cohort 效应差异不大时 |
| `cohort` | 只允许 cohort 异质性（所有时间同一 cohort 效应） | 时间效应差异不大时 |
| `event` | 只允许事件时间异质性（处理后第 k 期效应相同） | 想要更精确的事件研究 |
| `twfe` | 退化为传统 TWFE | **仅作对照，不推荐用于错时 DID** |

**注意**：`hettype(twfe)` 等价于 `xthdidregress twfe`，会产生负权重偏误——只用于与传统 TWFE 对照，不用于主估计。

#### jwdid vs csdid vs hdidregress 选择指南

| 场景 | 推荐 | 理由 |
|---|---|---|
| 标准错时 DID（线性） | `hdidregress aipw` 或 `csdid` 或 `jwdid` | 三者无协变量时数值一致；`hdidregress` 是官方，`csdid`/`jwdid` 更灵活 |
| 非线性结果变量（计数/二元） | **`jwdid`** | 唯一支持 poisson/logit 的选项 |
| 贸易/引力模型 | **`jwdid`** | 支持 `ppmlhdfe`（泊松伪最大似然） |
| 需要异质性约束 | **`jwdid`** | `hettype()` 选项 |
| 需要 `estat plot` 一键出图 | **`jwdid`** | `csdid` 需手动 coefplot |
| 需要 `pretrend` 检验 | **`jwdid`** | `estat event, pretrend` |
| 发顶刊（审稿人偏好） | `csdid` + `hdidregress` | 更广泛认可 |

#### 与 diff-diff 的对应关系

`jwdid` ≈ diff-diff 的 `WooldridgeDiD`（Python 估计量）。diff-diff 用 `jwdid` 作为 Stata 端的交叉验证锚点，确认 Python ETWFE 实现与 Stata 参考一致（SE 精度 ~1e-14）。

## 2. 合成控制：synth / synth_runner（少数处理单元 + 长前期）

适用场景：**处理单位只有一个（或极少数）**（加州控烟法、某省自贸区试点、某城市限行），且处理前期较长——此时普通对照组"谁都不像处理单位"，DID 的平行趋势假设很难令人信服。合成控制（Abadie, Diamond & Hainmueller 2010）从捐赠池（donor pool）里加权组合出一个"合成对照"，使其处理前轨迹与处理单位尽量重合。

```stata
ssc install synth, replace             // 社区包（自带示例数据 synth_smoking.dta）

use synth_smoking.dta, clear           // 加州 Prop 99（1989 年生效）经典案例
tsset state year

* state==3 为加州；1989 年起处理
synth cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 ///
      cigsale(1988) cigsale(1980) cigsale(1975), ///
      trunit(3) trperiod(1989) xperiod(1980(1)1988) ///
      nested fig keep(synth_smoking_out)
```

语法要点：

- `trunit(#)`：处理单位的**数值型** id（字符串先 `encode`，见 `stata-did` skill 第 9 节）；`trperiod(#)`：首个处理期。
- 预测变量可加期段：`beer(1984(1)1988)` 取 1984–1988 均值（注意：synth 包的 numlist 是 `start(1)end` 形式，不是 `start:end`；后者会被 synth 报 `invalid numlist r(121)`），`cigsale(1988)` 取单年值；不带期段的变量按 `xperiod()` 范围取均值。**预测变量只能用处理前期的信息**——混入处理后期等于偷看未来。
- `nested`：嵌套优化（多局部最优时更稳，推荐常加）；`allopt` 更彻底但更慢。
- `keep(file)`：把实际值与合成值存成 `.dta` 供后续画图；`fig`：直接出趋势对照图。

结果解读：`e(W)` 是捐赠池权重（哪些州、各占多少），`e(V)` 是预测变量权重；处理后各期 `e(Y_treated) - e(Y_synthetic)` 即各期效应（gap）。**pre-period 拟合越好（RMSPE 越小），post 期 gap 越可信。**

**推断：synth 不给 SE**——标准做法是 placebo 置换（ADH 2015）：把处理"假装"分给每个控制单位重跑，看真实处理的 post/pre RMSPE 比在全部 placebo 分布里的排名。手工循环繁琐，用 `synth_runner`（Galiani & Quistorff 2017）自动化：

```stata
ssc install synth_runner, replace
synth_runner cigsale beer(1984(1)1988) lnincome retprice age15to24, ///
    trunit(3) trperiod(1989) gen_vars

single_treatment_graphs, trlinediff(-1)   // 真实效应 vs 全部 placebo 效应
effect_graphs , trlinediff(-1)            // 效应与 placebo 分布对照
pval_graphs                               // 各期 placebo p 值
```

`gen_vars` 生成 `effect`（各期 gap）、`pre_rmspe`、`post_rmspe`、`lead`（相对期）等变量，可直接二次作图。多处理单位、错时时点时用 `d(处理哑变量)` 选项替代 `trunit()/trperiod()`，逐单位估计并聚合。

## 3. 合成 DID：sdid（合成控制 × DID 的结合）

Arkhangelsky et al. (2021, *AER*)：同时给**单位**（像 synth）和**时期**加权，再跑加权 DID。比 synth 多了单位固定效应（允许持久水平差），比 DID 多了数据驱动的权重——通常 pre-period 拟合与稳健性都更好。Stata 实现：`sdid`（Clarke & Pailañir，SSC）。

```stata
ssc install sdid, replace

* 语法骨架：sdid 结局 组变量 时间变量 处理哑变量
* 处理哑变量 = 处理单位 × 处理后（treat_post 型 0/1，不是 cohort 成员变量！）

* 本地模拟例：39 个对照州 + 1 个处理州 × 20 期，第 15 期起处理
clear
set seed 20260817
set obs 800
gen state = ceil(_n/20)
gen year  = mod(_n-1, 20) + 1
gen treat = (state==1 & year>=15)
gen y     = 5 + 0.1*year + 0.5*(state==1) + 1.2*treat + rnormal(0, 1)

sdid y state year treat, vce(bootstrap) reps(50) seed(20260817) graph
```

常用选项：

- `vce()`：`bootstrap`（通用，默认推荐）/ `jackknife`（仅面板可用，更快）/ `placebo`（大捐赠池）/ `noinference`。
- `method(sdid|sc|did)`：同一框架切换 合成 DID / 纯合成控制 / 普通 DID——**三方法一行对照**，与 diff-diff 的 `SyntheticDiD` / `SyntheticControl` / `DifferenceInDifferences` 一一对应。
- `covariates(varlist, projected)`：协变量调整（`optimized` 为默认算法）。
- `graph`：效应图 + 权重图；结果存在 `e(ATT)`、`e(se)`、`e(series)`。
- 错时采用：v2+ 原生支持，按处理 cohort 分别估计后聚合（面板下可与 `hdidregress aipw` 互为稳健性对照）。

**何时用 sdid 而非 synth**：处理前存在持久水平差（synth 拟合不动）、或想要标准误而不只 placebo 排名。**何时用 sdid 而非 hdidregress**：处理单位极少、需要权重透明可展示（论文里报告哪些对照单位进入了合成）。

与 diff-diff 的对应关系：`sdid` ≈ `SyntheticDiD`（含 bootstrap 推断）；`synth` + synth_runner placebo ≈ `SyntheticControl` + `in_space_placebo()`。

### did_imputation 详解：BJS 插补法

`did_imputation` 是 Borusyak, Jaravel & Spiess (2024) 实现的**插补法** DID 估计量（SSC）。与 `csdid`/`jwdid` 的"逐组×逐期估计后聚合"或"饱和交互回归"不同，`did_imputation` 采用**三步插补法**：先用未处理观测估计 Y(0) 模型，再外推到处理观测得到 tau = Y - Y(0)，最后聚合。其独特卖点是 `leaveout` 方差修正（BJS 附录 A.9），这是**唯一**的 Stata 实现。

#### 安装

```stata
ssc install reghdfe, replace         // 依赖（如果未装）
ssc install did_imputation, replace  // 主包
```

#### 核心语法

```stata
did_imputation Y i t Ei [if] [in] [aw], ///
    [fe(i t)] [controls(varlist)] [unitcontrols(varlist)] ///
    [horizons(numlist)] [leaveout] [autosample] ///
    [pretrends(#)] [shift(#)] [cluster(varname)]
```

| 参数/选项 | 含义 | 默认 |
|---|---|---|
| `Y` | 结局变量 | 必填（位置参数 1） |
| `i` | 面板单位 id | 必填（位置参数 2） |
| `t` | 时间变量 | 必填（位置参数 3） |
| `Ei` | 首次处理期（缺失 = 从未处理） | 必填（位置参数 4） |
| `fe(i t)` | 固定效应结构 | 默认 `fe(i t)`（双向 FE） |
| `controls(varlist)` | 时变协变量 | — |
| `unitcontrols(varlist)` | 单位特定趋势 | — |
| `horizons(numlist)` | 报告哪些事件期（0, 1, 2, ...） | 默认仅报告总体 ATT |
| `leaveout` | **有限样本方差修正**（BJS 附录 A.9） | 默认关闭 |
| `autosample` | 自动剔除无法插补的观测 | 默认关闭（报错） |
| `pretrends(k)` | 平行趋势检验（k 个 pre-trend 系数） | 0（不检验） |
| `shift(#)` | 预期效应期数 | 0 |
| `cluster(varname)` | 聚类变量 | — |

#### 语法对比：did_imputation vs csdid/jwdid

| 维度 | `did_imputation` | `csdid` / `jwdid` |
|------|------------------|-------------------|
| 参数风格 | **位置参数** `Y i t Ei` | **命名参数** `y, ivar() tvar() gvar()` |
| 从未处理编码 | `Ei` 缺失（`.`） | `gvar = 0` 或 `.` |
| FE 规格 | `fe(i t)` 灵活组合 | 固定（个体 + 时间） |
| 事后聚合 | `horizons(0/5)` 直接报告 | `estat event` 事后聚合 |
| 方差修正 | `leaveout`（唯一实现） | 无 |

#### 完整工作流示例

```stata
* 0. 安装（一次性）
ssc install reghdfe, replace
ssc install did_imputation, replace

* 1. 数据准备
* first_treat = 首次处理期；缺失 = 从未处理
use my_panel, clear

* 2. 基本估计（总体 ATT）
did_imputation y id year first_treat

* 3. 事件研究（按 horizon 报告）
did_imputation y id year first_treat, horizons(0/5) autosample

* 4. leaveout 方差修正（推荐）
did_imputation y id year first_treat, horizons(0/5) leaveout autosample

* 5. 平行趋势检验（5 个 pre-trend 系数）
did_imputation y id year first_treat, pretrends(5)
* 结果：pre1-pre5 系数 + e(pre_F) + e(pre_p) + e(pre_df)

* 6. 预期效应（anticipation = 2 期）
did_imputation y id year first_treat, horizons(0/5) shift(2)

* 7. 单位特定趋势
did_imputation y id year first_treat, horizons(0/5) unitcontrols(year)

* 8. 灵活 FE（如：州×年 FE）
did_imputation y id year first_treat, fe(i t#state) horizons(0/5)
```

#### `leaveout` 方差修正：为什么重要？

BJS 附录 A.9 指出：标准插补法的方差估计在有限样本下有偏（因为处理观测也参与了 Y(0) 模型的估计）。`leaveout` 选项通过留一法修正此偏：

- **无 `leaveout`**：方差可能低估（过于乐观）
- **有 `leaveout`**：方差更准确（有限样本一致）

**这是 `did_imputation` 的独特卖点**——其他包（csdid/jwdid/hdidregress）都没有此选项。diff-diff 的 Python 实现 `ImputationDiD(leave_one_out=True)` 是唯一的跨语言对应。

#### `fe()` 灵活 FE 规格

`did_imputation` 支持任意 FE 组合，比 csdid/jwdid 更灵活：

```stata
* 标准双向 FE
did_imputation y id year Ei, fe(i t)

* 州×年 FE（县级数据）
did_imputation y county year Ei, fe(i t#state)

* 无 FE（仅控制变量）
did_imputation y id year Ei, fe(.)

* 单位×星期几 FE（高频数据）
did_imputation y id date Ei, fe(i#dow t)
```

#### 何时用 did_imputation vs csdid/jwdid

| 场景 | 推荐 | 理由 |
|---|---|---|
| 想要最高效估计（同质效应） | **`did_imputation`** | 插补法在同质效应下标准误最小 |
| 想要 `leaveout` 方差修正 | **`did_imputation`** | **唯一实现** |
| 想要单位特定趋势 | **`did_imputation`** | `unitcontrols()` 选项 |
| 想要灵活 FE 规格 | **`did_imputation`** | `fe()` 任意组合 |
| 想要 DR/IPW/Reg 三方法 | `csdid` | 唯一提供 |
| 非线性结果变量 | `jwdid` | 唯一支持 poisson/logit |
| 想要一键出图 | `jwdid` | `estat plot` |
| 想要 hettype 约束 | `jwdid` | `hettype()` 选项 |
| 官方内置 | `hdidregress` | Stata 18+ |

#### 与 diff-diff 的对应关系

`did_imputation` ≈ diff-diff 的 `ImputationDiD`（Python 估计量）。diff-diff 用 `did_imputation` 作为 Stata 端的交叉验证锚点，确认 Python 实现与 Stata 参考一致（SE 精度 ~1e-9，leaveout SE 精度 ~1e-9）。

## 4. `reghdfe` 事件研究（手动哑变量）

`hdidregress` / `xthdidregress` 是 Stata 18+ 内置的错时 DID 异质性估计；Stata 17 及更早，社区包 `reghdfe`（Sergio Correia）的事件研究写法是主流——构建"相对时间"哑变量、手动选参考期、用 `reghdfe` 跑。这条脉络对阅读旧论文与维护旧代码至关重要。

```stata
* 1. 构造相对时间（事件时间）
gen rel_time = year - treat_year if treated == 1
replace rel_time = 0 if treated == 0     // 对照组所有期都映射到参考期

* 2. 生成每期一个哑变量（除参考期）
tab rel_time, gen(time_to_event)
drop time_to_event11                      // 假设 rel_time=-1 作参考期

* 3. 跑事件研究（双向 FE + 聚类稳健 SE）
reghdfe y (time_to_event*), absorb(id year) cluster(id)
coefplot, keep(time_to_event*) vertical ///
    yline(0) xline(-0.5, lpattern(dash)) ///
    title("Event study (reghdfe manual dummies)") ///
    scheme(s1mono)
```

`coefplot` 画出的每点对应一个相对时间的事件期系数；pre-treatment 期（负 rel_time）应不显著、落在零线附近，post-treatment 期（正 rel_time）开始显著——这就是"事件研究图"的视觉判读。

**Fix**：参考期选择影响整张图的解读——常选 `rel_time = -1`（处理前一期）；太长或太短的参考期都会让事件期系数估计有偏。

## 5. 8 步 practitioner 工作流（Baker et al. 2025）

跳过诊断步骤 = 不可靠结论。以下 8 步是 `igerber/diff-diff` 项目从学术最佳实践中凝练的工作流，**全部 8 步都能在 Stata + stataskills did 内执行**——`diff-diff` 只是把流程命名约定化了，Stata 生态每个命令都能映射。

### 步骤 1 — 定义目标参数

明确你要估计什么：

| 目标参数 | Stata 估计量 |
|---|---|
| ATT（平均处理效应） | `didregress` / `xtdidregress`（见 `stata-did` skill） |
| ATT(g, t)（cohort × 时期） | `hdidregress` + `estat aggregation, cohort`（见 `stata-did` skill） |
| ATT_es(e)（事件研究） | `hdidregress` + `estat aggregation, dynamic`（见 `stata-did` skill） |

明说是否加权（绝大多数情况下未加权；survey 数据见 [Roth et al. 2023](https://www.nber.org/papers/w31203)）。

### 步骤 2 — 陈述识别假设

至少明说三种：

- **平行趋势**（哪种变体？无条件的 / conditional on covariates / PT-GT-Nev / PT-GT-NYT）— 详见 Roth et al. (2022) § 3.1。
- **无预期**（no anticipation）：处理前一期，处理组不改变行为。
- **重叠**（overlap）：处理组与对照组在协变量分布上有共同支撑。

### 步骤 3 — 测试平行趋势

```stata
didregress (y) (treat), group(id) time(t)
estat ptrends                          // 数字检验（注意 staggered 时此检验不可靠）
estat trendplot                        // 图形诊断
```

**关键提醒**（来自 Roth 2022）：
- simple 2x2：`estat ptrends` 的 p > 0.05 是必要不充分条件。
- staggered：`estat ptrends` 失效，必须看 CS / SA 事件研究的 pre-period 系数。
- **不显著的 pre-trends 不证明 PT 成立**——只是没证据拒它。

### 步骤 4 — 选估计量

| 设计特征 | 推荐估计量 | Stata 命令 |
|---|---|---|
| simple 2x2 | DiD / TWFE | `didregress` / `xtdidregress`（见 `stata-did` skill） |
| staggered adoption | CS / SA / BJS（**不是** plain TWFE） | `hdidregress aipw` / `xthdidregress aipw`（见 `stata-did` skill） |
| staggered + 想做 DR/IPW/Reg 三方法对照 | CS 估计量 | `ssc install csdid`（第 1 节） |
| staggered + 非线性结果变量（计数/二元） | ETWFE | `ssc install jwdid`（第 1 节） |
| staggered + 想要 leaveout 方差修正 / 单位特定趋势 / 灵活 FE | BJS 插补法 | `ssc install did_imputation`（第 1 节） |
| 少数处理单元 | Synthetic Control / Synthetic DiD | `ssc install synth`（第 2 节）/ `ssc install sdid`（第 3 节） |
| 复杂共同因子 | TROP | `ssc install trop` |
| 内生选择 + 因子 | TROP / Imputation | 社区包 |

跑前先用 `estat bdecomp`（错时）或 `reghdfe`（手动 TWFE）诊断 TWFE 偏误大小。

### 步骤 5 — 估计并核对聚类数

```stata
xtdidregress (y x1 x2) (treat), group(id) time(t) vce(cluster id)
* 或：didregress (y x1 x2) (treat), group(id) time(t) wildbootstrap(reps(99) rseed(...))
```

**先打印 cluster 数**：

```stata
levelsof id, local(ids)
display "N clusters = `:list sizeof ids'"     // 至少 ≥ 50 才用 cluster-robust；< 50 改 wildbootstrap / DLang
```

规则（Bertrand et al. 2004）：聚类数 < 50 → wild bootstrap 或 `aggregate(dlang)`；≥ 50 → 默认 cluster-robust SE。

### 步骤 6 — 敏感性分析

不能只报主估计。必报：

- **Honest DiD**（Rambachan & Roth 2023）——平行趋势假设可能违反时的稳健 CI 上界：

  ```stata
  * 需要 ssc install honestdid（社区包）
  didregress (y) (treat), group(id) time(t)
  honestdid, m(0)         // M=0 表示允许 PT 违反的大小为 0（即原 PT 成立）
  honestdid, m(0.5)       // M=0.5 允许 PT 违反幅度 ≤ 0.5 SD（更宽松）
  ```

  报告 `M=0` 与 `M=0.5` 下的稳健 CI——这是审稿人最爱要的稳健性检查。
- **Placebo tests**（虚假检验）：用未受处理的时间窗口做"伪政策"分析，看系数是否接近零。
- **协变量敏感性**：带 vs 不带协变量两套结果对比，说明识别是否由条件分布驱动。

### 步骤 7 — 异质性

```stata
hdidregress aipw (y x1) (treat), group(id) time(t)

* 按 cohort 聚合（处理在哪一年入场）
estat aggregation, cohort graph

* 按事件研究聚合（暴露期长度）
estat aggregation, dynamic graph
```

**不要只报单一 ATT**——不同 cohort 的处理效应可能差异巨大（异质性处理效应是错时 DID 偏误的根源）。

### 步骤 8 — 稳健性

至少跑 2-3 个估计量对照：

- `didregress`（TWFE）vs `hdidregress aipw`（双重稳健）vs `csdid`（CS 估计量）
- 报"带协变量"与"不带协变量"两套结果
- 报 pre-trends 与稳健 CI 上下界

在论文里把这些数字放进一个对比表，让读者看估计量的稳定范围——单一估计量不可信。

### 工作流总结

| 步 | 输出 |
|---|---|
| 1 | 目标参数定义 |
| 2 | 假设明文化 |
| 3 | 平行趋势检验 + 图 |
| 4 | 估计量选择（含 TWFE 偏误诊断） |
| 5 | 估计结果 + 聚类数核对 |
| 6 | Honest DiD + placebo + 协变量敏感性 |
| 7 | 异质性（cohort × event-time） |
| 8 | 多估计量稳健性对照 |

> **关键提醒**：`igerber/diff-diff` 的 `get_llm_guide("practitioner")` 返回该工作流的 Python API 映射——可直接喂给 AI Agent 做 DID 自动化分析；Stata 用户可手按此 8 步操作。

## 方法选择决策树

用户描述 DID 场景时，按以下逻辑自动推荐最合适的估计量。**优先级从上到下**——匹配到第一条就推荐，不要继续往下。

### 场景路由表

| 用户场景特征 | 推荐方法 | 理由 |
|-------------|---------|------|
| 处理单位只有 1 个或极少数 | `synth`（第 2 节）/ `sdid`（第 3 节） | 合成控制 / 合成 DID，从捐赠池构建合成对照 |
| 简单 2x2 DID（一组处理、一组对照、单时点） | `didregress` / `xtdidregress`（见 `stata-did` skill） | 官方内置，最简单，estat 诊断丰富 |
| 错时 DID + 结果变量是计数/二元（如就诊次数、是否住院） | `jwdid method(poisson)` 或 `jwdid method(logit)`（第 1 节） | **唯一**支持非线性模型 |
| 错时 DID + 想要 `leaveout` 方差修正（有限样本更准确） | `did_imputation, leaveout`（第 1 节） | **唯一**实现 BJS 附录 A.9 |
| 错时 DID + 想要单位特定趋势（unit-specific trends） | `did_imputation, unitcontrols(year)`（第 1 节） | `unitcontrols()` 选项 |
| 错时 DID + 想要灵活 FE 规格（如州×年 FE） | `did_imputation, fe(i t#state)`（第 1 节） | `fe()` 任意组合 |
| 错时 DID + 想做 DR/IPW/Reg 三方法对照 | `csdid method(dr)`（第 1 节） | 唯一提供三种估计方法 |
| 错时 DID + 想要一键出图 | `jwdid` + `estat plot`（第 1 节） | `estat plot` 一键事件研究图 |
| 错时 DID + 想要内置平行趋势检验 | `jwdid` 或 `did_imputation`（第 1 节） | `estat event, pretrend` 或 `pretrends(k)` |
| 错时 DID + 想要异质性约束 | `jwdid hettype(event/cohort/time)`（第 1 节） | `hettype()` 选项 |
| 错时 DID + 默认（无特殊需求） | `hdidregress aipw`（见 `stata-did` skill） | 官方内置，estat 诊断丰富，默认推荐 |

### 特征对照矩阵

| 特征 | didregress | hdidregress | csdid | jwdid | did_imputation |
|------|-----------|-------------|-------|-------|----------------|
| 内置命令 | ✅ | ✅ | ❌ SSC | ❌ SSC | ❌ SSC |
| 错时 DID | ❌ | ✅ | ✅ | ✅ | ✅ |
| 非线性模型 | ❌ | ❌ | ❌ | ✅ poisson/logit | ❌ |
| DR/IPW/Reg 方法 | ❌ | aipw | ✅ 三方法 | ❌ | ❌ |
| leaveout 方差修正 | ❌ | ❌ | ❌ | ❌ | ✅ **唯一** |
| 单位特定趋势 | ❌ | ❌ | ❌ | ❌ | ✅ |
| 灵活 FE 规格 | ❌ | ❌ | ❌ | ❌ | ✅ |
| estat plot | ✅ | ✅ | ❌ | ✅ | ❌ |
| pretrend 检验 | estat ptrends | estat ptrends | 手动 | ✅ estat | ✅ pretrends |
| hettype 约束 | ❌ | ❌ | ❌ | ✅ | ❌ |
| 控制组选择 | — | notyet | notyet/never | notyet/never | — |

### AI Agent 选择逻辑

当用户描述 DID 场景时，按以下顺序检查：

1. **处理单位数量**：只有 1 个或极少数？ → `synth` / `sdid`
2. **处理时点**：单时点？ → `didregress` / `xtdidregress`（见 `stata-did` skill）
3. **结果变量类型**：计数/二元？ → `jwdid method(poisson/logit)`
4. **方差修正需求**：要 leaveout？ → `did_imputation, leaveout`
5. **FE 需求**：要灵活 FE（如州×年）？ → `did_imputation, fe()`
6. **估计方法需求**：要 DR/IPW/Reg？ → `csdid method(dr)`
7. **出图需求**：要一键出图？ → `jwdid` + `estat plot`
8. **默认**：`hdidregress aipw`（官方内置，最稳妥，见 `stata-did` skill）

## 事后命令速查

| 命令 | 适用估计 | 作用 |
|---|---|---|
| `estat simple` | csdid | 简单聚合 ATT（总体效应） |
| `estat group` | csdid | 按 cohort（首次处理年份）聚合 |
| `estat event` | csdid | 按事件时间聚合（事件研究系数） |
| `estat simple` | jwdid | 简单聚合 ATT（总体效应） |
| `estat group` | jwdid | 按 cohort 聚合 |
| `estat calendar` | jwdid | 按时间聚合（每年总体 ATT） |
| `estat event` | jwdid | 按事件时间聚合（事件研究系数） |
| `estat plot` | jwdid | 事件研究图（一键出图） |
| `estat event, pretrend` | jwdid | 平行趋势检验（pre-treatment ATT 联合为零） |
| `horizons(0/5)` | did_imputation | 按事件期报告 ATT（直接在估计时指定） |
| `pretrends(k)` | did_imputation | 平行趋势检验（k 个 pre-trend 系数 + F 检验） |
| `leaveout` | did_imputation | 有限样本方差修正（BJS 附录 A.9，唯一实现） |

## 关键陷阱速查

1. **`synth` 的 `trunit()` 只认数值 id，预测变量只能用处理前期**：字符串州名/国名先 `encode`（见 `stata-did` skill 第 9 节）；预测变量混入处理后期信息会让合成单位"偷看未来"，估计完全失效。
   **Fix**：`encode` 后用数值 id；期段写法 `beer(1984(1)1988)` 的上限 ≤ `trperiod()-1`；跑完先查 pre-period RMSPE 与平衡表（处理 vs 合成的预测变量均值差）。
2. **`synth` 没有内置 SE / p 值**：只报点估计与 `fig` 图就投稿，会被审稿人打回。
   **Fix**：用 `synth_runner ... , gen_vars` 跑 placebo 置换推断，`single_treatment_graphs` + `pval_graphs` 报 RMSPE 比排名（ADH 2015 标准做法）；捐赠池太小（< 10 个控制单位）时 placebo 排名分辨率不足，论文中明说推断粒度限制。
3. **`sdid` 的处理变量是 treat×post 哑变量，不是 cohort 成员变量**：传入"是否属于处理州"（全期 = 1）会把处理前期也当处理后，系数偏到零。
   **Fix**：先 `gen treat = (state==1 & year>=15)` 再 `sdid y state year treat, ...`；面板数据可用 `vce(jackknife)`（更快），重复截面 jackknife 不可用、改用默认 `bootstrap`。
4. **`csdid` 的 `gvar()` 编码**：从未处理单位必须编码为 `0` 或 `.`（缺失），不能用 `9999` 等哨兵值——`csdid` 内部用 `gvar==0` 或 `missing(gvar)` 识别 never-treated，用错会把所有单位都当作处理组，结果完全错误。
   **Fix**：`replace first_treat = 0 if never_treated` 或 `replace first_treat = . if never_treated`；跑完 `tab first_treat` 确认 never-treated 组的编码；`gvar()` 只接受数值型，字符串先 `encode`（见 `stata-did` skill 第 9 节）。
5. **`jwdid` 的 `method()` 必须配合 `group` 选项**：非线性模型（poisson/logit）下，用个体固定效应会导致 incidental parameter problem；`jwdid` 在 `method()` 非空时自动切换为 `group` 固定效应，但手动写 `group` 更明确。
   **Fix**：`jwdid y x, ivar(id) tvar(t) gvar(g) method(poisson) group`；线性模型（默认 reghdfe）不需要 `group`，但加了也不报错。
6. **`did_imputation` 的 `Ei` 编码**：从未处理单位的 `Ei` 必须是**缺失值**（`.`），不能用 `0` 或 `9999`——`did_imputation` 用 `missing(Ei)` 识别 never-treated；`0` 会被当作"在第 0 期处理"，结果完全错误。注意：这与 `csdid`/`jwdid` 的 `gvar` 编码（`0` = 从未处理）**不同**。
   **Fix**：`replace Ei = . if never_treated`；跑完 `tab Ei, missing` 确认 never-treated 组的编码是 `.`（缺失），不是 `0`。

## 参考文献与延伸阅读

- **Callaway & Sant'Anna (2021)** "Difference-in-differences with multiple time periods." *Journal of Econometrics* 225(2): 200-230. — `csdid` 的理论基础。
- **Wooldridge (2023)** "Simple Approaches to Nonlinear Difference-in-Differences with Panel Data." *The Econometrics Journal* 26(3): C31-C66. — `jwdid`（ETWFE）的理论基础。
- **Rios-Avila (2021)** `jwdid`: Stata module for ETWFE. SSC s459114. — `jwdid` 的 Stata 实现。
- **Borusyak, Jaravel & Spiess (2024)** "Revisiting Event Study Designs: Robust and Efficient Estimation." *Review of Economic Studies*. — `did_imputation`（插补法）的理论基础。
- **Goodman-Bacon (2021)** "Difference-in-differences with variation in treatment timing." *Journal of Econometrics* 225(2): 254-277. — `estat bdecomp` 的理论基础。
- **Sun & Abraham (2021)** "Estimating dynamic treatment effects in event studies with heterogeneous treatment effects." *Journal of Econometrics* 225(2): 200-230. — `eventstudyinteract` 的理论基础。
- **Abadie, Diamond & Hainmueller (2010)** "Synthetic Control Methods for Comparative Case Studies." *JASA* 105(490): 493-510. — `synth` 的理论基础。
- **Abadie, Diamond & Hainmueller (2015)** "Comparative Politics and the Synthetic Control Method." *AJPS* 59(2): 495-510. — placebo 置换推断（RMSPE 比排名）的来源。
- **Galiani & Quistorff (2017)** "The synth_runner package: Utilities to automate synthetic control estimation using synth." *Stata Journal* 17(4): 834-849. — 多处理单位 + placebo 自动化。
- **Arkhangelsky, Athey, Hirshberg, Imbens & Wager (2021)** "Synthetic Difference-in-Differences." *American Economic Review* 111(12): 4088-4118. — `sdid` 的理论基础。
- **Bertrand, Duflo & Mullainathan (2004)** "How much should we trust differences-in-differences estimates?" *QJE* 119(1): 249-275. — DID 推断问题的奠基讨论（cluster SE、必要聚类数等）。
- **Roth, Sant'Anna, Bilinski & Poe (2022)** "What's Trending in Difference-in-Differences? A Synthesis of the Recent Econometrics Literature." — 错时 DID 的最新综述。
- **Baker et al. (2025)** "How Practice Meets Theory in DiD: An 8-Step Practitioner's Workflow." — [diff-diff 仓库](https://github.com/igerber/diff-diff) 提炼的实操工作流。
- **Rambachan & Roth (2023)** "A More Credible Approach to Parallel Trends." *Review of Economic Studies*. — Honest DiD（平行趋势违反下的稳健 CI）。
- **Princeton DSS 教程**：https://libguides.princeton.edu/stata-did — wdipol.dta 案例数据来源。

## 验证

- 本 skill 的社区包（csdid / jwdid / did_imputation / synth / sdid）由 `verify/verify-synth-sdid.do` 覆盖：
  - 数据：`csdid` 部分用本地模拟数据（40 units × 10 periods，2 cohorts，`set seed` 固定）；`data/synth/synth_smoking.dta`（加州 Prop 99 经典案例，47045 字节，来源 scunning1975/mixtape，MIT 许可；下载脚本 `data/synth/download_synth_smoking.sh`，字节校验 EXPECTED_SIZE=47045，变化需团队确认）；`sdid` 部分用本地模拟数据（800 obs，39 对照 + 1 处理 × 20 期）。
  - 模式：
    - `bash verify/run-verify.sh did`（默认）：社区包已装则 PASS；未装则用 `cap which` 跳过关键命令、log 末尾打 `__COMMUNITY_PACKAGE_MISSING__<pkg>__` sentinel，仍 PASS（适合 CI / 网络受限环境）。
    - `bash verify/run-verify.sh did --community`：缺任一必需包（csdid / jwdid / did_imputation / synth / sdid）即 BAD，强制本地"真验证"。
    - `synth_runner` / `drdid` / `hdfe` 标记为可选——缺包仅打 sentinel，不影响 PASS。
  - 网络受限时本节方法与 `synthdid` R 包 / diff-diff 的 `SyntheticDiD` 同源，可跨语言替代。
- 运行：`bash verify/run-verify.sh did`（默认）/ `bash verify/run-verify.sh did --community`（强制）；全量六个 skill：`bash verify/run-verify.sh`。
