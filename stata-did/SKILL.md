---
name: stata-did
description: 帮助用户用 Stata 内置 DID 命令族做双重差分分析。Use when needing 政策评估 / 双重差分 / DID / DiD / difference-in-differences / 平行趋势检验 / 事件研究 / 错时处理 staggered DID / 三重差分 DDD / 异质性处理效应 / ATET 估计 / wild bootstrap 推断 / 经典手工 DID（xtreg + 交互项）/ 字符串组变量 encode / 手工平行趋势图 / 平行趋势假设被拒的应对 / reghdfe 事件研究 / eventdd csdid eventstudyinteract 错时 DID 替代命令 / 合成控制 synth / synth_runner placebo 置换推断 / 合成DID sdid / 少数处理单元 donor pool / synthetic control / synthetic difference-in-differences。覆盖 didregress（重复截面）、xtdidregress（面板）、hdidregress / xthdidregress（异质性稳健）四个内置估计命令与 trendplot / ptrends / granger / aggregation / atetplot / bdecomp 事后诊断，另含 synth / synth_runner / sdid 社区包（少数处理单元场景）；附 Princeton DSS 教程案例的应对流程。内置命令示例语法经 Stata 19.5 实测可复现（verify/verify-did.do），社区包需 ssc install。
---

# Stata 双重差分：didregress 命令族（DID / DDD / 错时处理）

本 skill 对应 Stata 官方 DID 命令族（源自 Stata 19 宣传单 [Causal inference: Difference-in-differences] 的命令体系）：`didregress`、`xtdidregress`、`hdidregress`、`xthdidregress` 及 `estat` 事后诊断，全部为**内置命令**，无需 `ssc install`。第 12–15 节补充主流社区包（reghdfe / eventdd / csdid / eventstudyinteract / synth / synth_runner / sdid），需 `ssc install`。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 安装与版本

```stata
version 19.5                       // 本仓库版本政策：首行钉住
* didregress / xtdidregress：Stata 17+（causal 模块）
* hdidregress / xthdidregress：Stata 18+（异质性稳健估计量）
help didregress                    // 官方手册 [CAUSAL] didregress
```

## 命令选择表

| 数据结构 | 处理时点 | 推荐命令 | 说明 |
|---|---|---|---|
| 重复截面 | 单时点 | `didregress` | 两组×多期独立截面 |
| 重复截面 | 单时点 + 双组维度 | `didregress` + 双 `group()` | 三重差分 DDD |
| 面板 | 单时点 | `xtdidregress` | 需先 `xtset` |
| 面板（长前期） | 单时点，处理单位极少（1 至几个） | `synth` / `sdid`（社区包） | 合成控制 / 合成 DID，见第 14–15 节 |
| 重复截面/面板 | 错时（staggered） | `hdidregress` / `xthdidregress` | TWFE 在错时下有偏，用异质性稳健估计量 |

共同语法骨架：`命令 (结局变量 [协变量]) (处理变量), group(组变量) time(时间变量)`——**处理变量必须放在第二对括号里**，估计目标是 ATET（处理组的平均处理效应）。

---

## 1. 基础 DID：didregress（重复截面）

```stata
* 数据结构：group 变量（0/1 或多组）、time 变量、treat = 处理组且处理后
didregress (satis) (treat), group(hospital) time(month)
estat trendplot                        // 平行趋势图（事后）
```

- 结局模型自动吸收组效应与时间效应，报告 ATET。
- 协变量放第一对括号：`didregress (satis age female) (treat), ...`。

## 2. 三重差分 DDD：group() 放两个组变量

处理状态必须在**两个组维度的组合**上变化（如：处理医院 × 参保患者）：

```stata
didregress (satis3) (treat3), group(hospital insured) time(month)
```

## 3. 推断选项：Donald–Lang 聚合与 wild bootstrap

```stata
* Donald–Lang：收缩到组×期均值后做推断（组数少时更稳）
didregress (satis) (treat), group(hospital) time(month) aggregate(dlang)

* 限制性 wild bootstrap：在零假设 ATET=0 下重抽，给 CI 与 p 值
* 注意是 rseed() 不是 seed()；reps() 默认 1000
didregress (satis) (treat), group(hospital) time(month) ///
    wildbootstrap(reps(99) rseed(20260816))
```

## 4. 面板 DID：xtdidregress

```stata
xtset id month
xtdidregress (satis x1) (treat), group(grp) time(month)
estat trendplot                        // 平行趋势图
estat ptrends                          // 事前平行趋势检验（注意不是 trends）
estat granger                          // Granger 型事前趋势检验
```

- 协变量与结局同在第一对括号：`(satis x1)`；第二对括号只放处理变量。
- `xtdidregress` 也支持 `aggregate(dlang)` 与 `wildbootstrap()`。

## 5. 异质性稳健 DID：hdidregress（错时处理 cohort）

错时处理（staggered adoption）下 TWFE 会混入"已处理组当对照"的负权重，产生偏误；`hdidregress` 提供异质性稳健估计量：

```stata
xtset id month
* 方法：twfe（双向固定效应）/ ra（回归调整）/ ipw / dr（双重稳健）
hdidregress twfe (y) (treat), group(id) time(month)

estat atetplot                         // 各 cohort 的 ATET 图
estat aggregation                      // 总体聚合（默认 overall）
estat aggregation, cohort              // 按 cohort 聚合
estat aggregation, dynamic             // 按处理暴露期聚合（事件研究视角）

hdidregress ra (y) (treat), group(id) time(month)
estat aggregation, overall
```

## 6. 面板异质性稳健版：xthdidregress

```stata
xtset id month                         // 必须先 xtset
xthdidregress twfe (y) (treat), group(id)
estat atetplot
estat aggregation, cohort
```

- **没有 `time()` 选项**：时间变量从 `xtset` 读取。

## 7. 处理效应分解：estat bdecomp（错时设计）

把总效应分解为 DID 效应、ATT 与选择项，直观展示错时下 TWFE 偏误来源：

```stata
* 前提 1：处理时点至少两个（错时设计）；前提 2：数据强平衡（每格一观测）
collapse (mean) y treat, by(group time)   // 个体级先收缩到组×期均值
didregress (y) (treat), group(group) time(time)
estat bdecomp                          // DID / ATT / 选择项分解
```

## 8. 经典手工 DID：`xtreg` + 交互项（Stata < 17 时代脉络）

Stata 17+ 的 `didregress`/`xtdidregress` 自动吸收组与时间固定效应并报告 ATET；Stata 17 之前没有这条官方路径，研究者手工构造"处理 × 事后"交互项并用 `xtreg` 跑。这一节保留这条历史脉络，方便阅读老论文与迁移到 `xtdidregress`。

```stata
* 1. 生成交互项：treat_post = treated × post
gen post    = (year >= 2000)
gen treated = (condlist)              // 1 = 处理组，0 = 对照组
gen treat_post = treated * post

* 2. 跑双向固定效应面板回归（处理 + 年固定效应）
xtreg trade treat_post i.year, fe vce(cluster id)
```

`treat_post` 的系数就是 DID 估计量；`i.year` 吸收年固定效应；`fe` 吸收个体固定效应；`vce(cluster id)` 在个体层聚类稳健 SE。这与 `xtdidregress (y) (treat_post), group(id) time(year)` 在代数上等价——后者只是把同样的估计写成声明式接口。

## 9. 组变量预处理：`encode` 把字符串变数值

`xtset` 只接受数值型组变量；如果原始数据组变量是字符串（如 country = "Australia"），必须先 `encode`：

```stata
xtset country year
* → "country is string variable; cannot be xtset"

encode country, gen(country_id)        // country_id 是 1..N 的整数 + 同名值标签
xtset country_id year                  // 现在 OK
xtdidregress (y) (treat), group(country_id) time(year)
```

**Fix**：`encode` 创建的新变量带值标签，所以 `tab country_id` 仍能看到原国家名；不要把 `country` 原变量与 `country_id` 混用。

## 10. 手工平行趋势图：`bysort` + `twoway line`

不依赖 `didregress` / `xtdidregress`，任何面板数据都能画——这在探索阶段（还没决定估计量）或跑 `reghdfe`/`csdid` 后很有用：

```stata
* 1. 收缩到 (年 × 组) 均值
bysort year treated: egen mean_y = mean(y)

* 2. 双线图（实线对照 + 虚线处理）+ 政策年参考线
twoway line mean_y year if treated==0, sort lpattern(solid) ///
   || line mean_y year if treated==1, sort lpattern(dash) ///
   || xline(2000, lpattern(dot))                      ///
   legend(label(1 "Control") label(2 "Treated"))    ///
   title("Pre/Post trend (manual, any data)")        ///
   scheme(s1mono)
graph export "output/pre_post_trend_manual.png", replace
```

**Fix**：先 `bysort year treated: egen mean_y = mean(y)` 才会出现两条线，否则散点太密；`sort` 选项让线按 x 轴排序；`xline(政策年)` 是判断平行趋势假设的视觉锚点。

## 11. 真实案例：平行趋势假设被拒时的应对

Princeton 教程 wdipol.dta 案例里，`xtdidregress (trade) (treated_post), group(country) time(year)` 后跑 `estat ptrends` 报 p=0.003——明确拒绝平行趋势原假设。

**这种时候标准做法**（按优先级）：

1. **看平行趋势图**：`estat trendplot`（或上面的手工 line 图）——判断是"处理前趋势本身就不平行"还是"预处理期太短/数据噪音大"。
2. **检查政策时间线**：是不是真的有"同期对照"？会不会某对照国其实在那段时间也有政策影响？通常需重读文献。
3. **加协变量平衡趋势差**：`xtdidregress (y x1 x2) (treat), group(id) time(t)`，看加协变量后 ptrends 是否变得不显著。
4. **改用合成 DID / 异质性稳健估计**：
   - `hdidregress aipw`——双重稳健，能在趋势差异存在时给出一致估计
   - `xthdidregress aipw`（面板版）
   - **不要简单地加更多控制变量**——这是过度反应，且会引入 bad control
5. **跑 Honest DiD 敏感性分析**（Rambachan & Roth 2023）：
   - 安装：`ssc install honestdid`（社区包，Stata 内置无）
   - 跑：`honestdid, m(0)` 与 `honestdid, m(0.5)`——报告 PT 违反幅度 ≤ 0.5 SD 下的稳健 CI 上界
   - 这是审稿人最常要求的稳健性检查；缺失等于"只信主估计"
6. **报告与解释**：在论文里诚实报告平行趋势假设被拒，给出**视觉证据 + 协变量敏感性 + 异质性估计 + Honest DiD 上下界的对照三角化**；不应隐藏或回避。

**关键提醒**：平行趋势被拒 ≠ DID 估计一定错，但意味着"因果解读"需要更强论证。

## 12. `reghdfe` 事件研究（手动哑变量）

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

## 13. 错时事件研究的替代命令：`eventdd` / `csdid` / `eventstudyinteract`

Stata 内置的 `hdidregress` 不是唯一选择；社区有三个主流替代：

| 命令 | 包 / 论文 | 优势 | 何时用 |
|---|---|---|---|
| `eventdd` | SSC：`ssc install eventdd` | 一行 `eventdd y i.year, timevar(rel_time) method(fe, cluster(id)) graph_op(...)` 出图；最简单 | 探索阶段、要快速看图时 |
| `csdid` | SSC：`ssc install csdid` | Callaway & Sant'Anna (2021) 估计量；双重稳健；可控制协变量；与 `hdidregress aipw` 同源思路 | 想做更严谨的异质性处理效应估计 |
| `eventstudyinteract` | SSC：`ssc install eventstudyinteract` | Sun & Abraham (2021) 异质性修正；估计"干净"事件研究系数，避免错时下 TWFE 偏误 | 想发顶刊 / 需要与传统 TWFE 估计对照时 |

**这三者都不是 Stata 内置**——需 `ssc install`；网络受限时（如中国大陆）安装可能失败，请改回 `hdidregress`。

## 14. 合成控制：synth / synth_runner（少数处理单元 + 长前期）

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

- `trunit(#)`：处理单位的**数值型** id（字符串先 `encode`，见第 9 节）；`trperiod(#)`：首个处理期。
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

## 15. 合成 DID：sdid（合成控制 × DID 的结合）

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

## 16. 参考文献与延伸阅读

- **Callaway & Sant'Anna (2021)** "Difference-in-differences with multiple time periods." *Journal of Econometrics* 225(2): 200-230. — `csdid` 的理论基础。
- **Goodman-Bacon (2021)** "Difference-in-differences with variation in treatment timing." *Journal of Econometrics* 225(2): 254-277. — `estat bdecomp` 的理论基础。
- **Sun & Abraham (2021)** "Estimating dynamic treatment effects in event studies with heterogeneous treatment effects." *Journal of Econometrics* 225(2): 200-230. — `eventstudyinteract` 的理论基础。
- **Abadie, Diamond & Hainmueller (2010)** "Synthetic Control Methods for Comparative Case Studies." *JASA* 105(490): 493-510. — `synth` 的理论基础（第 14 节）。
- **Abadie, Diamond & Hainmueller (2015)** "Comparative Politics and the Synthetic Control Method." *AJPS* 59(2): 495-510. — placebo 置换推断（RMSPE 比排名）的来源。
- **Galiani & Quistorff (2017)** "The synth_runner package: Utilities to automate synthetic control estimation using synth." *Stata Journal* 17(4): 834-849. — 多处理单位 + placebo 自动化（第 14 节）。
- **Arkhangelsky, Athey, Hirshberg, Imbens & Wager (2021)** "Synthetic Difference-in-Differences." *American Economic Review* 111(12): 4088-4118. — `sdid` 的理论基础（第 15 节）。
- **Bertrand, Duflo & Mullainathan (2004)** "How much should we trust differences-in-differences estimates?" *QJE* 119(1): 249-275. — DID 推断问题的奠基讨论（cluster SE、必要聚类数等）。
- **Roth, Sant'Anna, Bilinski & Poe (2022)** "What's Trending in Difference-in-Differences? A Synthesis of the Recent Econometrics Literature." — 错时 DID 的最新综述。
- **Baker et al. (2025)** "How Practice Meets Theory in DiD: An 8-Step Practitioner's Workflow." — [diff-diff 仓库](https://github.com/igerber/diff-diff) 提炼的实操工作流，详见第 17 章。
- **Rambachan & Roth (2023)** "A More Credible Approach to Parallel Trends." *Review of Economic Studies*. — Honest DiD（平行趋势违反下的稳健 CI），详见第 11 节第 4 步。
- **Princeton DSS 教程**：https://libguides.princeton.edu/stata-did — 本节 wdipol.dta 案例数据来源（实操模板）。

## 17. 8 步 practitioner 工作流（Baker et al. 2025）

跳过诊断步骤 = 不可靠结论。以下 8 步是 `igerber/diff-diff` 项目从学术最佳实践中凝练的工作流，**全部 8 步都能在 Stata + stataskills did 内执行**——`diff-diff` 只是把流程命名约定化了，Stata 生态每个命令都能映射。

### 步骤 1 — 定义目标参数

明确你要估计什么：

| 目标参数 | Stata 估计量 |
|---|---|
| ATT（平均处理效应） | `didregress` / `xtdidregress` |
| ATT(g, t)（cohort × 时期） | `hdidregress` + `estat aggregation, cohort` |
| ATT_es(e)（事件研究） | `hdidregress` + `estat aggregation, dynamic` |

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
| simple 2x2 | DiD / TWFE | `didregress` / `xtdidregress` |
| staggered adoption | CS / SA / BJS（**不是** plain TWFE） | `hdidregress aipw` / `xthdidregress aipw` |
| 少数处理单元 | Synthetic Control / Synthetic DiD | `ssc install synth`（第 14 节）/ `ssc install sdid`（第 15 节） |
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

## 事后命令速查

| 命令 | 适用估计 | 作用 |
|---|---|---|
| `estat trendplot` | didregress / xtdidregress | 平行趋势图 |
| `estat ptrends` | didregress / xtdidregress / hdidregress | 事前平行趋势检验 |
| `estat granger` | didregress / xtdidregress | Granger 型事前趋势检验 |
| `estat grangerplot` | didregress / xtdidregress | Granger 检验图 |
| `estat aggregation` | hdidregress / xthdidregress | overall / cohort / dynamic 聚合 |
| `estat atetplot` | hdidregress / xthdidregress | 各 cohort ATET 图 |
| `estat bdecomp` | didregress（错时 + 强平衡） | 效应分解 |

## 关键陷阱速查

1. **处理变量放错括号**：`(结局 协变量) (处理变量)`——把协变量放进第二对括号会报 `invalid treatment variable`。
   **Fix**：固定写作 `(结局 [协变量]) (处理变量)`；写完后 `assert _did_tvar` 看处理变量是否被正确识别；多模型时用 `estimates table, b(%9.3f) star` 核对每模型 ATET。
2. **`estat trends` 不存在**：事前趋势检验命令是 `estat ptrends`。
   **Fix**：只可能输错；自检 `help estat ptrends`；找不到时报 `unrecognized command` —— 改写为 `estat ptrends` 即可。
3. **`xthdidregress` 不接受 `time()`**：报 `option time() not allowed`，先 `xtset` 即可。
   **Fix**：`xthdidregress (y) (treat), group(id)`——**不写 time()**；时间变量从 `xtset id month` 自动读取；写错就报 option not allowed。
4. **wildbootstrap 种子是 `rseed()`**：写 `seed()` 报 `invalid 'reps'` 类错误。
   **Fix**：`didregress ..., wildbootstrap(reps(99) rseed(20260816))`；不要写 `seed()`（那是 sample 命令的）；reps 默认 1000，但小样本演示用 99 / 120 也行（.025*reps 整数时更快）。
5. **`estat bdecomp` 两前提**：处理时点 ≥ 2（错时设计）+ 数据强平衡（个体级先 `collapse` 到组×期均值）。
   **Fix**：错时设计 + 先 `collapse (mean) y treat, by(group time)` 收缩到组×期均值；不足 2 个处理时点报 `insufficient treatment cohorts`；非平衡数据报 `unbalanced data not allowed`。
6. **单时点 DID 用 TWFE 没问题，错时必须换稳健估计量**：`hdidregress` / `xthdidregress`，并配合 `estat aggregation, dynamic` 看事件研究图。
   **Fix**：处理时点 ≥ 2 时禁止用 `didregress` 的 TWFE 结果；改跑 `hdidregress`（重复截面）或 `xthdidregress`（面板），必看 `estat aggregation, dynamic graph` 事件研究图；bacon 分解（`estat bdecomp`）诊断错时下 TWFE 负权重。
7. **wild bootstrap 后 `estat vce` 不允许**：官方明确禁止。
   **Fix**：wildbootstrap 后只能看原始估计表（CI 用 percentile）；要看 vce 必须去掉 `wildbootstrap()` 重跑——CI 自动回归到默认 robust。
8. **2-cluster 时 wild bootstrap CI 不可识别**：当 `group()` 变量只有 2 个聚类（如 0/1 对照/处理），Stata 报告 `lower confidence bound not found`——这是 wild bootstrap 的已知边界，**不是错误**。
   **Fix**：组数 < 5 时不用 wildbootstrap，改用 `aggregate(dlang)`（Donald-Lang 聚合，少组时更稳）；或合并同类小组合成 ≥ 5 个组；研究设计中应保证至少 5 个独立处理单元（policy group）。
9. **`xtset` 字符串变量报错**：`xtset country year` 报 `country is string variable` —— xtset 只接受数值型组变量。
   **Fix**：`encode country, gen(country_id)` 把字符串转数值（自动带值标签）；后面所有 `group()`/`absorb()`/`cluster()` 用 `country_id`。
10. **平行趋势假设被拒的处理**：实操里 `estat ptrends` 报 p < 0.05 是常事——直接放弃 DID 是过度反应。
   **Fix**：按优先级（详见第 11 节）：(1) 看 `estat trendplot` 判断是"真趋势差"还是"数据噪音"；(2) 加协变量平衡趋势差；(3) 改用 `hdidregress aipw` 或 `xthdidregress aipw`；(4) 诚实报告 + 三角化论证，**不要简单加更多控制变量**（可能引入 bad control）。
11. **`reghdfe` 旧代码迁移到 `hdidregress`**：`reghdfe y (time_to_event*), absorb(...) cluster(...)` 是 Stata 17 主流写法；Stata 18+ 可改用 `hdidregress aipw (y) (treat), group(id) time(t)`，结果在代数上不等价（异质性估计 vs 平均 TWFE）——不能直接说"一样的"。
   **Fix**：迁移时在论文方法节明示；保留旧 `reghdfe` 输出作对照；不要混用两套估计量报同一个政策效应。
12. **`synth` 的 `trunit()` 只认数值 id，预测变量只能用处理前期**：字符串州名/国名先 `encode`（第 9 节）；预测变量混入处理后期信息会让合成单位"偷看未来"，估计完全失效。
   **Fix**：`encode` 后用数值 id；期段写法 `beer(1984(1)1988)` 的上限 ≤ `trperiod()-1`；跑完先查 pre-period RMSPE 与平衡表（处理 vs 合成的预测变量均值差）。
13. **`synth` 没有内置 SE / p 值**：只报点估计与 `fig` 图就投稿，会被审稿人打回。
   **Fix**：用 `synth_runner ... , gen_vars` 跑 placebo 置换推断，`single_treatment_graphs` + `pval_graphs` 报 RMSPE 比排名（ADH 2015 标准做法）；捐赠池太小（< 10 个控制单位）时 placebo 排名分辨率不足，论文中明说推断粒度限制。
14. **`sdid` 的处理变量是 treat×post 哑变量，不是 cohort 成员变量**：传入"是否属于处理州"（全期 = 1）会把处理前期也当处理后，系数偏到零。
   **Fix**：先 `gen treat = (state==1 & year>=15)` 再 `sdid y state year treat, ...`；面板数据可用 `vce(jackknife)`（更快），重复截面 jackknife 不可用、改用默认 `bootstrap`。

## 验证

- 本 skill 全部内置命令语法经 `verify/verify-did.do` 在 Stata 19.5（StataNow MP）批处理模式实测通过；数据全部本地模拟（`set seed` 固定），不依赖网络与额外 `.dta`。
- 第 14–15 节的 `synth` / `sdid` 为社区包（需 `ssc install`），由 `verify/verify-synth-sdid.do` 覆盖：
  - 数据：`data/synth/synth_smoking.dta`（加州 Prop 99 经典案例，47045 字节，来源 scunning1975/mixtape，MIT 许可；下载脚本 `data/synth/download_synth_smoking.sh`，字节校验 EXPECTED_SIZE=47045，变化需团队确认）；`sdid` 部分用本地模拟数据（800 obs，39 对照 + 1 处理 × 20 期）。
  - 模式：
    - `bash verify/run-verify.sh did`（默认）：社区包已装则 PASS；未装则用 `cap which` 跳过关键命令、log 末尾打 `__COMMUNITY_PACKAGE_MISSING__<pkg>__` sentinel，仍 PASS（适合 CI / 网络受限环境）。
    - `bash verify/run-verify.sh did --community`：缺任一必需包（synth / sdid）即 BAD，强制本地"真验证"。
    - `synth_runner` 标记为可选——缺包仅打 sentinel，不影响 PASS。
  - 网络受限时第 14–15 节方法与 `synthdid` R 包 / diff-diff 的 `SyntheticDiD` 同源，可跨语言替代。
- 运行：`bash verify/run-verify.sh did`（默认）/ `bash verify/run-verify.sh did --community`（强制）；全量六个 skill：`bash verify/run-verify.sh`。
- 真实研究中需注意：2-cluster 演示场景（如医院 0/1）跑 wildbootstrap 会报 CI 不可识别，应改用 `aggregate(dlang)`——见第 8 条陷阱。
