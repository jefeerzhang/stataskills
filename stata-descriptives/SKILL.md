---
name: stata-descriptives
description: Stata 描述统计、双分类变量分析、均值检验与相关回归。基于《A Gentle Introduction to Stata》第 6 版第 5–8 章：频数表/直方图/箱线图、交叉表与卡方、t 检验/比例检验、相关与简单回归、功效分析。含完整命令与解读逻辑。
---

# Stata 描述统计、表格与均值检验（本书第 5–8 章）

本 skill 浓缩自《A Gentle Introduction to Stata》第 6 版第 5–8 章。覆盖：单变量描述与图形、两分类变量交叉表与卡方、单/双均值与比例检验、相关与双变量回归、功效分析。

## 运行 Stata 的方式

- 本机 Stata：`C:\Program Files\StataNow19\StataMP-64.exe`。
- 批处理：`"C:\Program Files\StataNow19\StataMP-64.exe" /e do "脚本.do"`，结束生成同名 `.log`。
- 数据在仓库 `data/agis6/`；示例假设已 `cd` 到该目录。
- **中文作图规矩**：生成图形前先询问用户是否需要中文标签；默认英文作图，避免字体乱码。
- 报告 p 值惯例：Stata 输出 0.0000 时报告 `p < 0.001`，绝不写 p=0.000。

## 第 5 章 单变量描述统计与图形

### 集中趋势的选择
- 无序分类：只能众数；有序分类：众数+中位数（类别多时常用均值）；定量：一般均值，严重偏态用中位数。
- 偏态方向：正偏（右偏）时 mean > median（如收入）。

### 常用命令
```stata
tab1 sex marital polviews            // 多个变量各做一次频数表
summarize polviews, detail           // 均值/中位数(50%)/SD/偏度/峰度
ameans varlist                       // 算术/几何/调和均值
by sex, sort: summarize wwwhr        // 分组汇总
tabstat wwwhr, statistics(mean median sd iqr skewness kurtosis cv) by(sex) columns(statistics)
```
- `tabstat` 输出中位数标为 p50；CV=SD/mean 用于比较不同尺度变量的离散度；IQR=75 百分位−25 百分位。
- **Stata 的峰度正态值 = 3**（SAS/SPSS 报的是减 3 后的值）；kurtosis>10 有问题、>20 严重。

### 正态性检验
```stata
sktest wwwhr
```
- 看 Pr(Skewness)/Pr(Kurtosis)/联合 chi2；任一侧 p<0.05 即偏离正态。
- **陷阱（catch-22）**：大样本下小的偏离也显著（但大样本正态假设不关键）；小样本查不出大偏离（此时违反正态最致命）。别只看 p，结合偏度/峰度数值与直方图。

### 图形
```stata
* 直方图（离散变量当条形图用）
histogram polviews, discrete percent ///
    title(...) subtitle(...) note(...) xtitle(...) scheme(s1mono)
* 定量变量直方图，剔除极端值、按性别分面
histogram wwwhr if wwwhr < 25, freq by(sex)
* 水平箱线图（白线=中位数、箱=25–75 百分位、须=1.5 箱长、点=离群值）
graph hbox wwwhr if wwwhr < 25, over(sex) title(...) note(...)
* 饼图（类别变量）
graph pie marital
* 均值条形图
graph bar (mean) hrs1, over(sex)
```
- 菜单：Graphics → Histogram / Box plot / Pie chart / Bar chart；Overall 选项卡 Scheme 选 `s1mono`（黑白印刷友好）。
- 用户命令 `fre`（`ssc install fre`）比 tab1 详细：显示数值+标签、Percent/Valid/Cum 列，处理缺失极有用。
- 值标签加数值前缀：`numlabel _all, add`；移除：`numlabel _all, remove`。

## 第 6 章 两个分类变量的统计与图形

### 交叉表与卡方
```stata
use gss2006_chapter6, clear
tabulate sex abany, row               // row=行百分比（行放自变量，沿因变量列向比较）
tabulate sex abany, chi2 expected row // chi2=卡方, expected=期望频数
tabulate sex abany, chi2 row V        // V 必须大写！Cramér's V
```
- 解读：卡方值 = 观察频数与期望频数偏差的累积；报告 `χ²(1, N=1939) = 2.03`。
- **卡方是样本量的函数**：样本扩大 10 倍卡方也约扩大 10 倍——统计显著 ≠ 关系强。
- φ 系数（仅 2×2 表）：绝对值 0.0–0.19 弱、0.20–0.49 中、≥0.50 强；大表用 Cramér's V。
- **稀发事件陷阱**（阿司匹林例）：心梗发生率仅 1.33%，φ=−0.03 极弱且误导，但 OR=0.546 揭示阿司匹林使心梗几率降低 45.4%——解读表格要算 odds ratio。

### 优势比（OR）
- 2×2 表行 a/b、c/d：OR = (a/b)/(c/d)。
- OR>1：几率增加 `(OR−1)×100%`；OR<1：减少 `(1−OR)×100%`。
- 有序数据关联：`tabulate health happy, chi2 column gamma row taub V`；tau-b 判定 <0.2 弱、0.2–0.49 中、≥0.5 强；显著性用 z=tau-b/ASE，|z|≥1.96 显著 p<0.05。
- 表格直接录入（immediate 命令，行间用 `\`）：`tabi 215 269\172 244, chi2 row V`。
- 分类×定量汇总：
  ```stata
  * Stata 15（书）：table sex, contents(mean hrs1 sd hrs1 count hrs1)
  * Stata 17+：contents() 与 row 选项被 statistic() 取代
  table sex, statistic(mean hrs1) statistic(sd hrs1) statistic(count hrs1)
  table sex marital, statistic(mean hrs1) statistic(sd hrs1) statistic(freq) nformat(%9.1f)
  ```
- 卡方功效：先 `tab sex health, lrchi2 row`（必须用似然比卡方）。书的 `chi2power`（UCLA 包）已随 UCLA 服务器下线无法安装；可用近似替代（比较比例功效 `power twoproportions` 或参考 7.10 的 `power twomeans`）。

## 第 7 章 单/双均值检验

### 比例检验（要求 0/1 变量）
```stata
recode prayer (1=1 Approve) (2=0 Disapprove), gen(schpray)
prtest schpray == 0.5                    // 单样本：H0: p=0.5
prtest treat == control                  // 双样本（宽格式）
prtest cure, by(group)                   // 双样本（长格式）
```
- 0/1 变量的均值 = 比例；输出 z 值，双侧 p<0.05 拒绝 H0。

### t 检验
```stata
ttest hrs1 == 40 if wrkstat == 1                 // 单样本，H0: μ=40（注意双等号）
ttest inc if wrkstat == 1, by(sex)               // 双样本（长格式，组变量二分即可）
ttest maleinc == femaleinc, unpaired             // 双样本（宽格式）
ttest paeduc == maeduc                           // 配对（同一人两次测量/夫妻）
```
- 单样本 df=n−1；双样本 df=n1+n2−2。报告 `t(1418) = 18.92, p < 0.001`。
- 95% CI 不含 H0 值 ⇒ 显著；**统计显著 ≠ 实质显著**（大样本下微小差异也显著，如父母教育差 0.16 年）。
- 方差齐性：`sdtest inc if wrkstat == 1, by(sex)`（F 检验；大样本敏感、小样本迟钝，与 sktest 同病）。
- 效应量：
  ```stata
  esize twosample inc if wrkstat==1, by(sex) cohensd hedgesg pbcorr
  esizei 200 50000 25000 250 45000 24000, cohensd hedgesg pbcorr  // 文献只有 t 时用
  ```
  Cohen's d：0.20 小、0.50 中、0.80 大；point-biserial r：0.10 及以下小、0.10–0.30 中、>0.50 强；小样本用 Hedges's g。

### 功效分析（t 检验）
```stata
power twomeans 35 37, sd(10) power(0.90)   // 两组均值 35 vs 37、SD=10、功效 0.90
power twomeans 35 (36 37 38), sd(10) power(0.80)
```
- 默认 alpha=0.05；输出 N=总样本量。SD 粗估：SD≈(最高−最低)/4。
- 菜单：Statistics → Power and sample size → 比较两独立均值。

### 非参数替代
```stata
ranksum psmoke97, by(gender97)     // Mann–Whitney 秩和检验（有序/区间数据）
median psmoke97, by(gender97)      // 中位数检验（偏态变量，如收入）
kwallis stemcell, by(partyid)      // Kruskal–Wallis（3+ 组，第 9 章）
```
- 菜单：Statistics → Nonparametric analysis → Tests of hypotheses。

## 第 8 章 相关与双变量回归

### 散点图
```stata
use gss2006_chapter8_selected, clear   // 或 gss2006_chapter8（需先确认含所需变量）
set seed 111
sample 100, count                    // 大样本散点图失真，先抽子样本
twoway (scatter educ paeduc) if sex==1, ytitle(...) xtitle(...) title(...) legend(off)
twoway (scatter educ paeduc, jitter(6) jitterseed(222)) if sex==1, ...   // jitter 抖动重叠点
twoway (scatter educ paeduc) (lfit educ paeduc) if sex==1, ...           // 叠加回归线
twoway (scatter prestg80 hrs1) (lfitci prestg80 hrs1), ...               // 加置信带
```
- `set seed` 保证随机抽样可复现。`prestg80`/`hrs1` 的回归示例在 `gss2006_chapter8_selected` 中（见"双变量回归"）。

### binscatter（大样本替代）
```stata
ssc install binscatter
sysuse nlsw88, clear
keep if age > 34 & age < 45 & race < 3
binscatter wage tenure              // 分 20 个 bin 画均值点+回归线
binscatter wage tenure, rd(3.0)     // 断点 3 年
binscatter wage tenure, rd(3.0) by(race)
```

### 相关
```stata
correlate read write math science ses female        // 成列删除（listwise）
pwcorr read write math science ses female, obs sig star(5)   // 成对删除 + 显著性 + 星号
pwcorr ... , bon sig star(5)                        // Bonferroni 校正多重比较
```
- `correlate` 任一变量缺失即删整行（可能损失大量样本）；`pwcorr` 每对相关用全部可用观测。
- 强度判定：|r|=0.1 弱、0.3 中、0.5 强；显著性同时依赖 r 与 N（大样本 r=0.1 也显著——统计显著≠实质显著）。
- 排序相关（有序数据）：`spearman age liberal`。

### 双变量回归
```stata
regress prestg80 hrs1              // 默认输出含系数 95% CI
regress prestg80 hrs1, beta        // beta=标准化系数
```
- 输出解读：
  - R² = 自变量解释的方差比例（双变量回归中 R² = r²）；Root MSE ≈ 回归线周围 SD。
  - 方程：Estimated Y = b₀ + b₁X（_cons 是截距，b 是 X 每增 1 单位 Y 的期望变化）。
  - Beta（标准化回归系数）= 效应量（0.10 弱、0.30 中、0.50 强），**双变量回归中 β 恒等于 r**。
  - t = b/SE，df = N−2，报告 `t(2713) = 8.21, p < 0.001`。
- **外推陷阱**：回归线两端信息少、置信带两端宽；预测范围外（0 小时、140 小时/周）无意义。

### 相关的功效分析
```stata
power onecorrelation 0 0.20        // H0: r=0 vs Ha: r=0.20，功效 0.80，输出 N
```
- 菜单：Statistics → Power and sample size → 相关 → Fisher's z 检验。

## 关键陷阱速查

1. p 值报告 `p<0.001`，不写 0.000。
2. 统计显著 ≠ 实质显著：卡方随样本量膨胀、r=0.1 大样本也显著、t 检验任何差异都可能显著——始终结合效应量（φ/V、OR、Cohen's d、R²、β）解读。
3. sktest 与 sdtest 大样本敏感、小样本迟钝，结合数值与图形判断。
4. `V` 是 Stata 少见的必须大写的选项。
5. 比例检验前先把变量 recode 成 0/1。
6. 随机数先 `set seed` 保证可复现；`sample ..., count` 无放回、`bsample` 有放回。
7. 大样本散点图用 binscatter 或 jitter。
8. 外部命令安装：`ssc install fre binscatter`（实测可装）；书的 `chitable`/`chi2power`（UCLA 概率表/卡方功效辅助命令）已随 UCLA 服务器下线无法安装，非核心命令；查卡方临界值可用 `display invchi2(df, 0.95)` 替代（如 `invchi2(1, 0.95)` = 3.84）。
