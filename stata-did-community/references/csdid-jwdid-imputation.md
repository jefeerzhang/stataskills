---
name: stata-did-community-csdid-jwdid-imputation
description: 错时 DID 三大社区包参考：Callaway-Sant'Anna (csdid)、Wooldridge ETWFE (jwdid)、Borusyak-Jaravel-Spiess 插补法 (did_imputation)。覆盖 DR/IPW/Reg 三方法、leaveout 方差修正、poisson/logit 非线性模型、单位特定趋势、灵活 FE 规格。主文件见 stata-did-community/SKILL.md。
---

# stata-did-community-csdid-jwdid-imputation

> **加载时机**：主 SKILL.md 决策树已读完，遇到"错时 DID + 非默认需求"时加载本文件：csdid 用于 DR/IPW/Reg 三方法对照；jwdid 用于非线性模型；did_imputation 用于 leaveout 方差修正或灵活 FE。

> **边界约定**：本文件只补详细方法签名与工作流示例。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

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

#### Sun-Abraham (SA) interaction-weighted 等价说明

在异质性-robust 意义上，`csdid, method(dr)`（双重稳健默认）与 `method(ipw)`
在报告 cohort × event-time 聚合（`estat event` / `estat group`）时，与 **Sun & Abraham (2021)
interaction-weighted (SA-IW) 估计量**估计相同的 ATT(g,t)：

- **SA-IW 路径**：以 cohort × event-time 单元交互回归重新加权 TWFE 的负权
- **csdid DR/IPW 路径**：从 2×2 反事实矩估计出发再聚合
- 在 staggered 共同支撑下两者对 ATT(g,t) **渐近等价**
  （Sant'Anna & Zhao 2020 Theorem 2 + Callaway & Sant'Anna 2021 Theorem 2）

**何时显式提到 SA-IW**：用户问"Sun-Abraham 估计量怎么做"或论文引用 SA 2021 时 → 答
`csdid, method(dr)` + 解释 cohort × period 聚合即 SA 加权，并附 `estat event` 出图。
**不要写"用 R 的 `did_multiplegt_dyn` SA 选项"**：R 的 `did_multiplegt` **没有** SA 选项——
SA-IW 是 csdid / `eventstudyinteract` 系的产物。错路由到 R `did_multiplegt_dyn` 的 SA 选项
是错误（该选项不存在）。

**文献**：Sun, L., & Abraham, S. (2021). "Estimating dynamic treatment effects in event studies
with heterogeneous treatment effects." *Journal of Econometrics*, 225(2), 175-199.
https://doi.org/10.1016/j.jeconom.2020.09.006

#### `csdid, method(twostage)` — Gardner (2022) two-stage DiD

Gardner (2022) "Two-stage differences in differences" 把传统 2×2 DD 拆成两步：

1. **第一阶段**：把处理组的 post-period 用对照组的 pre→post 变化率"插补"（imputation），
   得到反事实 Y~。
2. **第二阶段**：对 imputed Y~ 与实际 Y 的差做组 × 期回归，权重由 multiplier bootstrap
   给出。

`csdid, method(twostage)` 实现了 Gardner 2-stage（**与 BJS 的 `did_imputation` 的设计差异**）：

- **BJS (`did_imputation`)**：用**全体未处理单位**拟合单一插补模型，所有 cohort 共享。
- **Gardner (`csdid twostage`)**：每个 cohort **单独插补**，更灵活但方差大。
- 两者都属于 imputation-based 估计量；区别在 imputation 模型的 granularity 与方差结构。

**适用**：处理时点较少（≤ 3 个 cohort）+ 想看 cohort-specific 估计 + 接受方差放大。
**不适用**：cohort 极多（≥ 10）——stage-1 自由度被吃光，估计退化。

```stata
* Gardner 2-stage：用 csdid 的 twostage
csdid y, ivar(id) time(t) gvar(g) method(twostage) notyet
estat simple                            // 总体 ATT（2-stage 矩）
estat event                             // 事件研究
estat group                             // 按 cohort 聚合
```

**文献**：Gardner, J. (2022). "Two-stage differences in differences." arXiv:2207.05943.
https://arxiv.org/abs/2207.05943

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

