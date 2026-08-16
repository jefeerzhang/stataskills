---
name: stata-regression
description: 帮助用户做方差分析、回归建模与功效分析。Use when needing 单因素 / 双因素 / 重复测量 ANOVA / ANCOVA（连续协变量必须加 c. 前缀，否则按分类处理）/ 多元回归诊断（VIF / Cook's D / 异方差稳健 SE / 中心化后再放二次项）/ 交互与非线性（margins + marginsplot 解读，不直接读主效应）/ 加权回归 [pweight=] / 逻辑回归（odds ratio 与 pseudo-R² 不是解释方差）/ margins 边际效应 / 嵌套模型 nestreg / 功效分析（power oneway / twoway / rsquared）/ 高维固定效应 reghdfe（2+ 层 FE / 面板双向 FE / 固定斜率 feslope / 多向聚类 vce(cluster fe1 fe2) / IV-GMM 吸收 FE / 自动剔除单点组）。配套 38 个 AGIS6 数据集。
---

# Stata 方差分析与回归建模（本书第 9–11 章）

本 skill 浓缩自《A Gentle Introduction to Stata》第 6 版第 9–11 章。覆盖：方差分析全家族、多元回归与诊断、逻辑回归与结果解读、各类功效分析。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`，内含全部输出。平台二进制路径与 Windows 等价命令见 `docs/run-stata.md`。
- 数据在仓库 `data/agis6/`；示例命令中的 `use 文件名, clear` 假定已 `cd` 到该目录。
- **中文作图规矩**：生成图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 第 9 章 方差分析（ANOVA）

- 报告惯例：Stata 输出 0.0000 时报告 `p < 0.001`，绝不写 p=0.000。

### 单因素 ANOVA
```stata
use partyid, clear
oneway stemcell partyid, bonferroni tabulate     // 分组变量 + Bonferroni 多重比较
anova stemcell partyid                           // 等价命令（配合 estat esize）
estat esize                                      // η²（eta-squared）
```
- 输出：F = MS(组间)/MS(组内)，报告 `F(3,42) = 12.46, p < 0.001`；Bartlett 检验方差齐性。
- 多重比较选项：Bonferroni / Scheffe / Sidak；`pwmean stemcell, over(partyid) effects cimeans mcompare(bonferroni)` 输出更丰富。
- 效应量 η² = 组间SS/总SS（0.01 小、0.06 中、0.14 大）；`estat esize, omega` / `, epsilon` 给校正版。
- 图形：`graph bar (mean) prestg80 if 条件, over(mobile16)`；`graph box stemcell, over(partyid)`。
- 非参数替代：`kwallis stemcell, by(partyid)`（比较中位数）。

### ANCOVA（协方差分析）
- **关键：连续协变量必须加 `c.` 前缀**，否则被当作分类变量（每个取值一个 dummy，浪费自由度）。数据集 `gss2006_chapter9`：
  ```stata
  use gss2006_chapter9, clear
  anova prestg80 mobile16 c.age if age > 29 & age < 60 & wrkstat==1
  margins mobile16, atmeans            // 调整均值（固定协变量在均值处）
  margins mobile16#sex, atmeans        // 分组×类别
  ```
- `margins` 输出 Adjusted predictions；对连续变量固定均值合理，对分类变量固定均值无意义。

### 双因素 ANOVA 与交互
```stata
use gss2006_chapter9_2way, clear
anova tvhours workfull married                  // 主效应
anova tvhours workfull married workfull#married // # 表示交互项
margins workfull#married
marginsplot, noci                               // 交互显著时两线不平行
```
- 交互写法：`A##B` 含主效应+交互；`A#B` 仅交互。

### 重复测量 ANOVA
```stata
use wide9, clear
reshape long test, i(id) j(time)               // 宽→长
xtset id
xtreg test                                      // 先算 ICC（rho）：ICC≥0.05 需校正
anova test id time, repeated(time)              // 输出含 Huynh-Feldt/Greenhouse-Geisser/Box 校正
margins time
```
- 报告时把三种自由度校正的 p 都给出；Box 过于保守。

### ICC（测量一致性）
```stata
use intraclass, clear
xtset group
xtreg medicare
```
- rho = ICC。**一致性不能用简单相关**（子代总比母代高 2 分时相关仍=1.0）。

### ANOVA 功效分析
```stata
power oneway, ngroups(3) delta(.1(.05).4) power(.8)   // Cohen's f：0.10 小/0.25 中/0.40 大
power twoway, nrows(2) ncols(3) power(0.80) n(100(20)300) factor(column)
power repeated, n(100(10)300) power(0.80) corr(0.60) nrepeated(4) ngroups(1)
```
- 菜单：Statistics → Power and sample size → ANOVA (multiple means)。

## 第 10 章 多元回归

### 基本模型
```stata
use ops2004, clear
regress env_con educat inc com3 hlthprob epht3, beta
```
- 输出：右上 F(k, N−k−1)、R²、Adj R²；系数表含 Coef（未标准化 b）、Std. Err.、t、P>|t|、Beta。
- 解读：b = 控制其他变量后 X 每变 1 单位 Y 的变化；β = 标准化权重（<0.20 弱、0.2–0.5 中、>0.5 强）。R²<0.1 弱、0.1–0.2 中、>0.3 强（领域相关）。
- 去掉 `beta` 选项即得系数 95% CI。

### 半偏相关（增量 R²）
```stata
pcorr env_con educat inc com3 hlthprob epht3   // 看 Semipartial Corr.² 列
```

### 残差诊断
```stata
regress env_con educat inc com3 hlthprob epht3
predict res, residual
sktest res                                     // 残差正态性
rvfplot, yline(0)                              // 残差 vs 拟合值（看异方差）
* 异方差稳健处理（只改 SE 与 p，参数不变）：
regress env_con educat inc com3 hlthprob epht3, vce(robust)
regress env_con educat inc com3 hlthprob epht3, vce(bootstrap, reps(1000))
```
- 离群/强影响：
  ```stata
  predict rstandard, rstandard
  list respnum env_con res rstandard if abs(rstandard) > 2.58 & rstandard < .
  dfbeta
  list respnum rstandard _dfbeta_1 if abs(_dfbeta_1) > 2/sqrt(3769) & _dfbeta_1 < .
  ```
  DFbeta 临界值 = 2/√N。
- 共线性：`estat vif`（VIF>10 或 1/VIF<0.10 有问题）；症状：β 全部不显著且超出 −1~1。

### 加权数据
```stata
regress env_con educat inc com3 hlthprob epht3 [pweight=finalwt], beta
```
- 加权回归自动使用稳健标准误；`sum of wgt` 应≈总人口或样本量（查文档确认权重类型）。

### 分类预测变量与因子变量
```stata
recode gender97 (1=1 Male) (2=0 Female), generate(male)   // 二分 dummy
regress smday97 age97 male psmoke97 i.race, beta          // i. 前缀自动生成 dummy（第一类为参照）
regress smday97 age97 male psmoke97 ib3.race, beta        // ib3. 改参照组
```
- k 个类别需 k−1 个 dummy；二分类变量的回归系数 = 控制其他变量后两组均值差；β 对 dummy 无意义。
- 检验一组系数（分类变量整体）：`test aa hispanic other`（F 检验）。
- 嵌套回归（分层）：`nestreg: regress smday97 (age97 male) (psmoke97) (aa hispanic other), beta`；块用括号，输出各块增量 R²。**nestreg 不支持因子变量记法**。

### 交互作用
```stata
regress inc i.male##c.educ, beta        // ## 含主效应+交互；i. 分类、c. 连续
margins male, at(educ=(8(2)18))
marginsplot, noci
```
- **存在显著交互时不能直接读主效应系数**；分别写各组的方程解读；不解释数据范围外的截距。
- 中心化：`summarize educ` 得 r(mean) → `generate educ_c = educ - r(mean)`；或 `ssc install center` 后 `center educ`。
- **不要跨群体比较标准化 β/相关**（依赖方差），要比比未标准化斜率。

### 非线性（二次项）
```stata
use https://www.stata-press.com/data/r15/regsmpl, clear
regress ln_wage c.ttl_exp##c.ttl_exp, beta    // c. 连续变量的平方
margins, at(ttl_exp=(0(2)28))
marginsplot
```
- 二次模型没有单一斜率；曲线在 −b₁/(2b₂) 处转向；线性系数是 x=0 处切线。显著交互/二次项都要看图解读。
- 中心化后再放二次项（截距=均值处估计）；零值无意义时（教育 0 年）应中心化。

### 多元回归功效
```stata
power rsquared 0.26, power(0.90) ntested(5)        // 总 R² 检验
power rsquared 0.30 0.40, power(0.9) ntested(2) ncontrol(3)  // 新增子集
```
- 效应量参考：R² 小 0.02、中 0.13、大 0.26。
- 注：书的 `powerreg`（UCLA 包）已随 UCLA 服务器下线；其 `r2f()/r2r()` 参数对应官方
  `power rsquared` 的 delta = R²/(1−R²) 形式（如 r2f(.2) → `power rsquared 0.25, ntested(3) power(0.90)`，实测 N=47）。

## 10.5 高维固定效应：`reghdfe`（扩展，教材未覆盖）

`reghdfe`（**Noah Constantine & Sergio Correia**，里士满联储）是处理多维固定效应的
Stata 社区包，实现 Correia (2017) 的估计器。它是 `areg` / `xtreg` 的一般化。

### 版本（2026-08 调研自 GitHub）
- **SSC 当前稳定版**：`6.12.3 (20aug2023)`（注意不是某些文档说的 5.x）
- **最新开发版**：`6.13.0 (09Jan2026)`（GitHub `master` 分支；实验性 `vce(dkraay #)`）
- 旧版 5.x 与 6.x 并存：用 `version(5)` 切回 5.x 行为

### 安装（必须先 compile ftools）
```stata
* ===== 推荐：6.x 开发版（含最新改进）=====
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
- **查版本**：`reghdfe, version` 看首行注释；或 `which reghdfe`

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
| v6.13.0 | 2026-01-09 | 加实验性 `vce(dkraay #)` Driscoll-Kraay SE |

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
reghdfe depvar indepvars, absorb(panelvar timevar) vce(dkraay 2)

* 固定斜率（per-group slope）
reghdfe depvar indepvars, absorb(fe1) feslope(indepvar fe1)      // fe1 内 in depvar 的斜率不同

* 个体固定效应（Constantine & Correia 2021；区别于固定斜率）
reghdfe depvar indepvars, absorb(fe1) indiv(firm) group(occ) aggregation(sum)

* 内存优化（大 N 救命，5 – 10x 节省）
reghdfe depvar indepvars, absorb(fe1 fe2) compact poolsize(1000)
```

### 高级选项速查
| 选项 | 用途 | 何时用 |
|---|---|---|
| `absorb(fe1 fe2 …)` | 多维 FE | 始终需要 |
| `vce(cluster ...)` | 聚类稳健 SE | 始终推荐（比 robust 更准） |
| `vce(dkraay #)` | Driscoll-Kraay SE（v6.13+） | 面板数据跨相关+自相关 |
| `vce(robust)` | 异方差稳健 SE | 简单场景 |
| `feslope(var fe)` | fe 内 var 的斜率不同 | 固定斜率模型 |
| `indiv() group() aggregation()` | 个体 FE | Constantine & Correia 2021 |
| `compact` + `poolsize(#)` | 内存优化 | 大 N + 内存吃紧 |
| `version(3)` / `version(5)` | 旧版行为 | 兼容性 |
| `residuals(varname)` | 保存残差 | 必须 estimate 时加，不能事后 `predict, resid` |
| ⚠️ `cache` | 复用变换 | **尚未完全支持**（GitHub TODO 仍在） |

### `vce(dkraay)` 示例（v6.13+，面板数据）
```stata
* Driscoll-Kraay 标准误：面板数据跨相关 + 自相关稳健
* 数字是滞后阶数（按面板 T 期长度与自相关跨度选）
sysuse auto, clear
* auto.dta 不是真 panel；演示语法（实际需要 id + time 变量）
reghdfe price weight length, absorb(rep78) vce(dkraay 2)
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
| 固定斜率 | ✅ `feslope()` | ❌（需手工 demean） |
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

## 第 11 章 逻辑回归

### 为什么用 logistic
- 二分类结果（离婚/患病/饮酒）。OLS 线性概率模型会预测出 <0 或 >1 的概率；估计的是 logit（与概率一一对应、与预测变量线性）。

### 模型拟合
```stata
use nlsy97_chapter11, clear
logistic drank30 age97 male pdrink97 dinner97   // 输出 odds ratio（OR）
logit drank30 age97 male pdrink97 dinner97      // 输出系数（logit 单位）
```
- 输出：LR chi2(4)（整体检验）、Log likelihood、Pseudo R2（McFadden）。
- **pseudo-R² 不是解释方差的百分比**，是相对仅截距模型的似然改进；pseudo-R² 低但 OR 重要的情况常见（如 lbw 例中 OR=2.02 但 pseudo-R²=0.021）。

### Odds ratio 解读
- 2×2 表手算示例（书 11.3，environ.dta）：
  ```stata
  use environ, clear
  tab2 environ libcand, row
  ```
  高环保关注者支持自由派候选人的 odds 是低关注者的 3.48 倍（OR=(7/3)/(4/6)）。
- OR>1：每单位增加 `(OR−1)×100%` 的几率；OR<1：减少 `(1−OR)×100%`。
- **多单位变化取幂不取乘法**：年龄 OR=1.17，15 岁 vs 12 岁 = `1.17^3 = 1.60`（`display 1.17^3`）。
- OR ≠ 风险比（risk ratio）：OR 描述几率、RR 描述概率，结果不罕见时差别大；`ssc install oddsrisk` 可转换。
- 用户命令 `listcoef`（spost 包）：不在 SSC 索引，需从 GitHub 镜像手动安装
  `listcoef.ado` 及其依赖 `_penocon.ado`、`_perhs.ado`、`_pecats.ado`、`_pesum.ado`（放 `ado/plus/l/` 与 `ado/plus/_/`）；
  `listcoef, help` 输出单位变化 OR 与 **1 个 SD 变化的 OR**（e^bStdX，用于比较非二分变量）；`listcoef, help percent` 给百分比版。

### 假设检验
```stata
logistic drank30 male dinner97 pdrink97
estimates store a
logistic drank30 age97 male dinner97 pdrink97
lrtest a                                        // 似然比检验（偏好 LR 而非 Wald）
test pdrink97 dinner97                          // 一组系数（Wald）
test maeduc=faeduc                              // 两系数相等
```
- 单系数 Wald z 即输出中的 z（有些软件报 Wald chi2(1)）；也可 `ssc install lrdrop1` 后 `lrdrop1` 一键逐个 LR 检验。

### margins：解释概率
```stata
logit drank30 age97 i.black pdrink97 dinner97
margins, dydx(black) atmeans                  // 概率差：黑人比白人饮酒概率低 x 个百分点
margins black, atmeans                        // 报告概率本身
margins, at(pdrink97=(1 2 3 4 5)) atmeans     // 连续变量：预测概率随取值变化
marginsplot                                   // 画图
* 含交互的模型：
logit drank30 age97 i.black##c.pdrink97 dinner97
margins black, at(pdrink97=(1 2 3 4 5)) atmeans
marginsplot
```
- `dydx()` 关注变量、`atmeans` 协变量固定在均值、`at()` 指定取值或区间 `(0(10)100)`。

### 嵌套逻辑回归
```stata
nestreg: logistic drank30 (male) (age97) (dinner97 pdrink97)
```

### 功效分析
- 逻辑回归（MLE）比 OLS 需要更大样本，简单模型也最好 ≥100 观测。
- 书的 `powerlog`（UCLA 包）已随 UCLA 服务器下线无法安装；其计算的是"单一连续预测变量
  在 logistic 回归中的功效"（X 在均值处概率 p1、+1SD 处概率 p2）。官方命令无直接等价
  （`power logit` 不被支持），可用两比例检验近似：`power twoproportions p1 p2, power(0.90)`
  （注意：这是两独立组比例检验，与 powerlog 的回归功效框架不同，仅作近似参考）。

## 关键陷阱速查

1. `anova` 中连续协变量必须 `c.` 前缀，否则按分类处理。
2. 存在显著交互/二次项时：不直接读主效应/线性系数；用 margins+marginsplot 看图；不解释范围外截距。
3. pseudo-R² 不是解释方差；OR 不是风险比；多单位 OR 变化要取幂。
4. nestreg 不支持因子变量记法（先 generate 平方项等）。
5. 加权回归自动用稳健 SE；检查 sum of wgt 合理性。
6. 不要跨群体比较标准化 β/相关。
7. Stata 峰度正态值=3（SAS/SPSS 报减 3 值）。
8. p 值报告 p<0.001。
