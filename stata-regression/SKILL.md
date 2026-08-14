---
name: stata-regression
description: Stata 方差分析与回归建模。基于《A Gentle Introduction to Stata》第 6 版第 9–11 章：ANOVA/ANCOVA/双因素/重复测量、多元回归（诊断/交互/非线性/加权）、逻辑回归（odds ratio/margins/嵌套模型）、功效分析。含完整命令与解读逻辑。
---

# Stata 方差分析与回归建模（本书第 9–11 章）

本 skill 浓缩自《A Gentle Introduction to Stata》第 6 版第 9–11 章。覆盖：方差分析全家族、多元回归与诊断、逻辑回归与结果解读、各类功效分析。

## 运行 Stata 的方式

- 本机 Stata：`C:\Program Files\StataNow19\StataMP-64.exe`；批处理：`"…\StataMP-64.exe" /e do "脚本.do"`，结束生成同名 `.log`。
- 数据在仓库 `data/agis6/`；示例假设已 `cd` 到该目录。
- **中文作图规矩**：生成图形前先询问用户是否需要中文标签；默认英文作图。
- 报告 p 值惯例：Stata 输出 0.0000 时报告 `p < 0.001`。

## 第 9 章 方差分析（ANOVA）

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
- **关键：连续协变量必须加 `c.` 前缀**，否则被当作分类变量（每个取值一个 dummy，浪费自由度）：
  ```stata
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
