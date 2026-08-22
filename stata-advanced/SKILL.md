---
name: stata-advanced
description: Stata 高级方法：Cronbach α / 因子分析 / 结构方程 sem / 多重插补 mi / 多层模型 mixed / 项目反应理论 irt。对应教材第 12–16 章。触发词：信效度 / 因子分析 / SEM / 插补 / 多层模型 / IRT / Cronbach。
---

# Stata 进阶测量与现代方法（本书第 12–16 章 + 附录 A）

本 skill 浓缩自《A Gentle Introduction to Stata》第 6 版第 12–16 章与附录 A。覆盖：量表构建与信效度、因子分析、SEM/GSEM、多重插补、多水平模型、项目反应理论。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`，内含全部输出。平台二进制路径与 Windows 等价命令见 `docs/run-stata.md`。
- 数据在仓库 `data/agis6/`；示例命令中的 `use 文件名, clear` 假定已 `cd` 到该目录。
- **中文作图规矩**：生成图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 第 12 章 测量、信度与效度

- 报告惯例：Stata 输出 0.0000 时报告 `p < 0.001`，绝不写 p=0.000。

### 构建量表
- 反向题先反码（高分=特质强），用 `pre()` 加前缀、`label()` 指定值标签昵称：
  ```stata
  use gss2006_chapter12, clear
  recode empathy2 empathy4 empathy5 (1=5 "Does not describe very well") ///
      (2=4) (3=3) (4=2) (5=1 "Describes very well"), pre(rev) label(empathy)
  egen empathy = rowmean(empathy1 revempathy2 empathy3 revempathy4 revempathy5 empathy6 empathy7)
  ```
- 用 `rowmiss()` 数缺失，限定作答 ≥75% 再算均分：
  ```stata
  egen miss = rowmiss(empathy1 revempathy2 empathy3 revempathy4 revempathy5 empathy6 empathy7)
  egen empathya = rowmean(同左) if miss < 3
  ```
- **不要用 rowtotal 把缺答当 0**；必须总分时：`generate total = 均分 * 条目数`。

### 信度
```stata
* Cronbach's alpha（内部一致性；α>0.80 良好、>0.70 尚可）
alpha empathy1 revempathy2 empathy3 revempathy4 revempathy5 empathy6 empathy7, asis item min(5)
* 二分条目：同一命令，α 即 KR-20
alpha newartmus1 newartmus2 newartview newartinfo newartmus3, asis item
* 重测信度（稳定性）
use retest.dta, clear
correlate score1 score2, obs sig
* 评分者一致性：kappa 命令是 kap（不是 kappa！）
use kappa1.dta, clear
kap coder1 coder2
```
- alpha 选项：`asis`（不改条目符号）、`item`（条目分析：item-rest 相关、删该条后的 α）、`min(5)`（至少答 5 题）、`generate(新变量)`（生成均分）。
- **删条目提升 α 是利用偶然性**，谨慎。
- κ 判定（Landis & Koch）：<0.20 Poor、0.21–0.40 Fair、0.41–0.60 Moderate、0.61–0.80 Good、0.81–1.00 Very good；κ 只奖励超出偶然一致的部分。
- α 特性：条目多即使平均相关低 α 也高；条目少需高相关。

### 效度
- 内容效度：专家评议；CVR = (ne−N/2)/(N/2)。
- 效标关联：连续效标用相关（r=0.30 中等支持、0.50 强支持），二分效标用 logistic。
- 构念效度：已知组比较（`ttest hope, by(work)` + `esize twosample hope, by(work)`）、收敛/区分效度（`pwcorr hope cesd1 newhapmar ..., obs sig`，期望正相关=收敛、负相关=区分）。

### 因子分析（PCF）
```stata
use gss2006_chapter12_selected, clear
recode natspac ... natsci (1=3 "Too little") (2=2 "About right") (3=1 "Too much"), prefix(r) label(revnat)
factor rnatspac rnatenvir rnatheal rnatcity rnatcrime rnatdrug rnateduc rnatrace rnatarms rnatfare rnatroad rnatsoc rnatchld rnatsci, pcf
screeplot                    // 碎石图（拐点处舍去后续因子）
rotate                       // 正交旋转（Varimax，默认）
rotate, promax               // 斜交旋转
estat common                 // 斜交旋转后的因子相关矩阵
```
- PCF（主成分因子）= SPSS 的 PCA，解释全部方差，用于建单维量表；PF（`factor, pf` 默认）解释共享方差，用于找维度。
- 解读：特征值 >1 才保留；载荷 >0.4 视为好指标；uniqueness 高说明该条目与因子关联弱。
- 打分：`factor ... , pcf` 后 `predict libfscore, norotate`（因子分，均 0 SD 1）或 `egen 均分 = rowmean(载荷高的条目)`。

## 第 13 章 结构方程模型（sem / gsem）

### 用 sem 做线性回归
```stata
use flourishing_bmi, clear
regress bmi age children incomeln educ quickfood, beta   // OLS 对照
sem bmi <- age children incomeln educ quickfood          // sem 语法：因变量在箭头左
sem bmi <- age children incomeln educ quickfood, standardized
estat eqgof                                              // 求 R²
```
- sem 的优点：①可画路径图；②`method(mlmv)` 用 FIML 处理缺失（假设 MAR，优于 regress 的整例删除假设 MCAR）：
  ```stata
  sem bmi <- age children incomeln educ quickfood, method(mlmv) standardized
  ```
- 缺失探索与辅助变量：
  ```stata
  misstable summarize bmi age children incomeln educ quickfood, generate(miss_)
  pwcorr miss_bmi miss_incomeln miss_educ miss_quickfood age children incomeln educ quickfood, sig
  ```
  把与缺失指示变量相关的辅助变量加入模型（辅助变量 4–5 个，残差可共变）：
  ```stata
  sem (bmi <- age children incomeln educ quickfood) ///
      (gender minority alienation <- bmi age numberchildren incomeln educ quickfood), ///
      covariance(e.gender*e.minority e.gender*e.alienation e.minority*e.alienation) ///
      method(mlmv) standardized
  ```

### gsem：广义模型（logistic 等）
```stata
recode bmi (0/29.999=0) (30/60=1), gen(obese)
logit obese age children incomeln educ quickfood          // 对照
gsem obese <- age children incomeln educ quickfood, family(binomial) link(logit)
estat eform                                              // 输出 odds ratio
```
- gsem 可用 family：gaussian/identity、binomial(bernoulli)/logit、multinomial/logit、ordinal/logit、poisson/log、nbreg/log、gamma/log。
- **gsem 不能用 method(mlmv)**（只有整例删除）。

### 路径分析与中介
- 先拟合不含中介模型（直接路径显著才继续）；再拟合含中介模型；用 teffects 分解效应：
  ```stata
  sem (quickfood <- educ incomeln) (bmi <- educ incomeln quickfood)
  estat teffects
  ```
  - 直接效应变不显著而间接显著 → 完全中介；直接变小但仍显著 → 部分中介。
- **路径模型是关联不是因果**：同时测量的数据不能排除反向因果。

## 第 14 章 缺失值：多重插补

### 思路
- 三步：①生成多个完整数据集；②每集分析；③合并（参数取均值、SE 合并组内组间变异）。插补值只含模型+辅助变量的信息，不是"作弊"。
- 假设：MCAR（完全随机，罕见）；MAR（可由观测变量解释，现实）——mi 要求 MAR；无法检验 MAR，靠辅助变量支撑。

### 纳入哪些变量
- 必含因变量；分析模型全部变量；解释缺失机制的辅助变量；跳过合法跳题与"无意义"变量；避免纳入自身缺失多的变量；插补**前**生成交互项与平方项（事后计算有偏）。

### 操作流程
```stata
use chapter13_missing, clear
misstable summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
misstable patterns ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm   // 1=完整；看整例删除损失
* 找辅助变量：生成缺失指示变量并 pwcorr/logit
quietly misstable summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm, generate(miss_)
pwcorr miss_ln_wagem miss_gradem miss_agem ..., obs sig

* 设置与插补
mi set flong                                   // 存储风格：wide/long/flong/mlong
mi register imputed ln_wagem gradem agem ttl_expm tenurem blackm
mi register regular not_smsa south
mi impute mvn ln_wagem gradem agem ttl_expm tenurem blackm, add(20) rseed(2121)
* 类别/计数变量用链式方程：mi impute chained ..., add(20)

* 分析
mi estimate, dftable: regress ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
```
- `add(20)`：额外 20 个完整数据集（现代建议 ≥20）；`rseed()` 保证可复现。
- 插补次数越多自由度越高；报告时说明 DF 已按插补数与缺失信息比例调整。
- R² 与标准化 β：`mi estimate` 不合并（Rubin 规则不适用），用社区命令 `mibeta`
  （不在 SSC 索引，需从 GitHub 镜像手动安装 `mibeta.ado`/`mibeta.sthlp` 到 `ado/plus/m/`）：
  ```stata
  mibeta ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm, fisherz miopts(vartable)
  ```
- **插补出范围外值（负值、小数性别）不要修正**：不截断、不四舍五入（早期做法引入偏倚）；除非是"不应插补"的缺失码 `.a`–`.z`（需先 recode 成 `.`）。

## 第 15 章 多层分析（mixed）

### 数据重塑（宽→长）
```stata
use longitudinal_mixed, clear
clonevar drink0 = drink98
clonevar drink2 = drink00
clonevar drink4 = drink02
clonevar drink6 = drink04
clonevar drink8 = drink06
clonevar drink10 = drink08
drop drink98 drink00 drink02 drink04 drink06 drink08
reshape long drink, i(id) j(wave)        // i() 个体、j() 时间
```
- 时间编码避免巨大数字（用 0,1,2,3 而非 0,4,8,12，否则二次项膨胀）。

### 建模前：个体轨迹可视化
- 先画 10–20 个个体的轨迹，直观判断截距和斜率的大致范围，再进入模型：
  ```stata
  twoway connected drink wave if id < 100, connect(L)
  ```
- 观察点：①截距大概在什么水平；②整体是上升还是下降；③个体间斜率差异大不大；④缺失值分布。

### 随机截距模型
```stata
mixed drink c.wave || id:                // 随机截距（个体起点不同、斜率相同）
estimates store linear
margins, at(wave=(0(2)10))
marginsplot
```
- 输出解读：固定部分 _cons（18 岁基线）、wave 系数（每增 1 岁变化）；随机部分 `var(_cons)`（截距方差，CI 不含 0 说明需要随机截距）、`var(Residual)`。
- 二次项：`mixed drink c.wave##c.wave || id:`；模型比较 `lrtest linear quadratic`（LR 对样本敏感，小改进也可能显著，算 PRE 看实际改善）。
- 时间当分类（自由函数形式）：`mixed drink i.wave || id:`。

### 随机系数模型
```stata
mixed drink c.wave || id: wave, cov(unstructured)   // wave 也有随机斜率；允许截距斜率相关
predict yhat_drink, fitted                          // 个体拟合线
```
- 随机部分 4 参数：var(wave)（斜率方差）、var(_cons)、cov(wave,_cons)（正相关=起点高者增得快）、var(Residual)。
- 加时不变协变量（性别）与交互：
  ```stata
  mixed drink c.wave i.male || id: wave
  mixed drink c.wave i.male c.wave#i.male || id: wave   // 允许性别差距随时间变化
  margins male, at(wave=(0(2)8))
  marginsplot
  ```
- **随机效应需要高层 20–30 组以上**（Snijders & Bosker），否则功效受限。

## 第 16 章 项目反应理论（IRT）

### 模型选择
- 二分条目：1PL（仅难度，即 Rasch）、2PL（难度+区分度）、3PL（加猜测参数）。
- Likert 条目（多分类）：**graded response model（GRM）**。
- IRT 的价值：条目难度分散覆盖整个连续体，可评估/缩短量表、做自适应测验；与简单加总（各条目等权）思路不同。

### 拟合 1PL / 2PL
```stata
use attitude, clear        // dn2 dn4 dn5 dn7 dn10（1=高自信 0=低自信）
irt 1pl dn2 dn4 dn5 dn7 dn10
estat report, byparm sort(b)            // 按难度排序
irtgraph icc, blocation                 // 条目特征曲线（blocation 标出难度）
irtgraph iif                            // 项目信息函数
irtgraph tif, se                        // 测验信息函数（含 SE 曲线）
predict rasch_score, latent             // 估计潜得分
```
- 1PL：共享 Discrim + 每题 Diff；难度接近的条目冗余可删。
- 2PL vs 1PL 的 LR 检验：
  ```stata
  irt 1pl dn2 dn4 dn5 dn7 dn10
  estimates store rasch
  irt 2pl dn2 dn4 dn5 dn7 dn10
  lrtest rasch
  ```
- 缺失值：IRT 默认用全部可用信息（每人至少答一题）；`irt 1pl ..., listwise` 只分析全答者（除非 MCAR 否则有偏）。

### 等级反应模型（GRM，Likert 条目）
```stata
use attitude, clear
irt grm n2 n4 n5 n7 n10                // 原始 4 点条目（负向题先反码）
irtgraph icc n4, blocation             // 边界特征曲线（逐题）
irtgraph iif
irtgraph tif, se
predict confidence, latent
```
- GRM 每题的每个响应类别有独立难度——"4 不再是 4"（同一选项在不同条目难度不同）。

### IRT 信度
- IRT 不用单一 α：信度 ρ = 1 − (1/信息量)，沿 θ 连续体波动。
  ```stata
  irt 2pl dn2 dn4 dn5 dn7 dn10
  irtgraph tif, se data(tif_2pl, replace) n(5) range(-2 2) nodraw
  use tif_2pl, clear
  generate rel_irt_2pl = 1 - (1/tif)
  ```
- 切点应用（执照考试等）关注切点附近信度。
- 菜单：Statistics → IRT (item response theory) Control Panel（Model/Report/Graph/DIF 页）。
- 扩展：部分信用模型（1PL 版 GRM）、`irt hybrid`（不同条目不同模型）、DIF（`difmh`、`diflogistic` 检验项目功能差异）。

## 附录 A 进阶资源

- UCLA 统计站：https://stats.idre.ucla.edu/stata/（首选，含 do-files 与视频）。
- 社区命令库 SSC：`ssc install 包名`；Statalist 论坛、Stata Blog（blog.stata.com）、Stata Journal（statajournal.com）。
- 进阶书：Cameron & Trivedi《Microeconometrics Using Stata》、Rabe-Hesketh & Skrondal《Multilevel and Longitudinal Modeling Using Stata》、Raykov & Marcoulides《A Course in IRT and Modeling with Stata》、Long & Freese《Regression Models for Categorical Dependent Variables Using Stata》。
- 获取数据：NLSY97（bls.gov）、ICPSR；变量数上限：Stata/IC 2,047、SE 32,767、MP 120,000。
- 后估计：Statistics → Postestimation（Postestimation Selector），"type a little, get a little"。

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证** 四件套。每条陷阱都给出可执行的修复 + 验证；Agent 在 SKILL.md 读到警告时即拿到完整修复路径。

1. 评分者一致性命令是 `kap`，不是 `kappa`
   - **触发**：写 `kappa rater1 rater2` 报 `kappa not an estimation command` 或只报录入冲突（kappa 是录入专用命令）。
   - **Fix**：一致性分析用 `kap rater1 rater2`；kappa（录入命令）只用于问卷录入冲突排查。跑错时 `kap` 会报 `variable not found` 反向指引。
   - **验证**：`kap rater1 rater2` 应输出 κ 系数 + SE；`kappa` 应报录入冲突列表。

2. 删条目提 α 是 capitalizing on chance
   - **触发**：看到 α < 0.7 就删条目（"提 α"），多次重复后 α 被人为推高，但结果不可复现。
   - **Fix**：不删条目提 α；按理论保留；用 `alpha, item` 看每条目 α，**只删理论缺陷条目**（如反向题未反向编码）。报告里说明删条理由，不报"提 α 后数值"。
   - **验证**：报告只报最终 α + 删条的理论理由；无"删条目提 α"操作。

3. gsem 不能用 method(mlmv)；交互/平方项要在插补前生成
   - **触发**：`gsem ... , method(mlmv)` 报 `method mlmv not allowed with gsem`；`mi set` 之后生成 `gen int_x_z = x*z` 在插补时不见交互项。
   - **Fix**：`sem` 走 `method(mlmv)` 处理缺失；`gsem` 含 logistic 等非线性 → 缺失值用 `mi estimate: gsem ...`；交互项 `gen int_x_z = x*z` 必须在 `mi set` 之前生成。
   - **验证**：交互项在插补数据集 `mi xeq` 输出中存在；`sem` 走 `method(mlmv)`，`gsem` 走 `mi estimate`。

4. 插补出"不可能值"不要修正
   - **触发**：跑 `mi predict imputed_*` 后看到负收入、年龄>120 等"不可能值"，直觉改成 `.`——但事后修改引入人为偏差。
   - **Fix**：跑 `mi predict imputed_*` 后**不修改**插补值（如负收入、年龄>120）；保留并 `summarize imputed_*` 报告分布即可；事后修会引入人为偏差。
   - **验证**：报告插补分布（`summarize imputed_income, detail`）+ 明说"保留插补原值，不事后修正"。

5. mi 假设 MAR；靠辅助变量支撑假设
   - **触发**：`mi impute chained` 不加辅助变量，MAR 假设无支撑，结果偏。
   - **Fix**：`mi impute chained ..., include(aux_vars)` 必须包含辅助变量（如同一理论框架下其他题目）；自检：`mi xeq: ...` 看辅助变量系数，若与插补项相关性强 → MAR 假设成立。
   - **验证**：`mi xeq: regress imputed_var aux_vars` 应有显著系数；不显著则 MAR 假设弱。

6. 多层模型高层需 20–30 组以上；时间编码避免大数字
   - **触发**：跑 `mixed y x || group: x` 但 group 数 < 20，组级 SE 估计不稳；时间变量用 2010–2020 的大数导致收敛慢。
   - **Fix**：跑 `mixed y x || group: x` 前 `tab group` 看组数；< 20 组用 `xtset id time` 转 panel 或换 `regress, cluster(group)` 稳健 SE；时间变量大数先 `egen time_c = std(time)` 中心化。
   - **验证**：跑前 `tab group` 看组数；< 20 时改用 `cluster(group)` 稳健 SE。

7. 路径模型≠因果模型
   - **触发**：写 `sem` 路径图后说"X 导致 Y"——sem 仅反映协变结构，不是因果识别。
   - **Fix**：`sem` 路径图只反映变量间协变结构；写报告避免"X 导致 Y"，用"X 与 Y 在控制 Z 后仍显著相关"；因果推断需额外识别策略（IV、RCT、DiD）。
   - **验证**：报告必含"相关""关联"等词；"导致""因果"仅在有识别策略时使用。

8. IRT 用测验信息函数看信度，不用单一 α
   - **触发**：跑 `irt 2pl items` 后报单一 α（如 Cronbach α = 0.85） 作为测验信度——IRT 假设下信度因 θ 而异。
   - **Fix**：跑 `irt 2pl items` 后用 `irtgraph tif` 看测验信息函数；不同 θ 区段信度不同，**报告"θ ∈ [-1, 1] 区段信度 > 0.8"**而不是单一 α。
   - **验证**：报告必含测验信息函数图 + θ 区段信度；无单一 α 报告。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「**主动反模式**」清单——「关键陷阱速查」是被动警告，本节是主动规范。Agent 在写 do-file 前必查一遍。

- ❌ **不要用 `kappa` 做评分者一致性**：`kappa` 是问卷录入命令，不是一致性分析。**替代**：一致性用 `kap rater1 rater2`；kappa 仅用于问卷录入冲突排查。
- ❌ **不要删条目提 α**：capitalizing on chance——多次重复后 α 被人为推高，结果不可复现。**替代**：用 `alpha, item` 看每条目 α，**只删理论缺陷条目**（如反向题未反向编码）；报告删条理由，不报"提 α 后数值"。
- ❌ **不要在 `gsem` 用 `method(mlmv)`**：报 `method mlmv not allowed with gsem`。**替代**：`sem` 走 `method(mlmv)`；`gsem` 含非线性用 `mi estimate: gsem ...`。
- ❌ **不要在 mi set 之后生成交互项**：插补时不见交互项。**替代**：交互项 `gen int_x_z = x*z` 必须在 `mi set` 之前生成。
- ❌ **不要事后修正插补值**（如负收入改为 0、年龄>120 改为 .）：引入人为偏差。**替代**：保留 `mi predict imputed_*` 原值，`summarize imputed_*` 报告分布，明说"不事后修正"。
- ❌ **不要在 < 20 组的数据跑 `mixed` 高层效应**：组级 SE 估计不稳。**替代**：< 20 组用 `xtset id time` 转 panel 或 `regress, cluster(group)` 稳健 SE；时间变量大数先 `egen time_c = std(time)` 中心化。
- ❌ **不要把 sem 路径系数说成"因果"**：sem 仅反映协变结构，不是因果识别。**替代**：报告用"X 与 Y 在控制 Z 后仍显著相关"；"导致""因果"仅在有识别策略（IV/RCT/DiD）时使用。
- ❌ **不要用单一 α 报 IRT 测验信度**：信度因 θ 而异，单一 α 误导。**替代**：用 `irtgraph tif` 看测验信息函数；报告"θ ∈ [-1, 1] 区段信度 > 0.8"。
- ❌ **不要在因子分析前不做 KMO / Bartlett 球形检验**：可能因子结构不适用。**替代**：`estat kaiser` / `factortest`（SSC）；KMO > 0.6 + Bartlett p < 0.05 才适合因子分析。
