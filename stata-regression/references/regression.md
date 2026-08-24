---
name: stata-regression-regression
description: 多元回归参考：基本模型 / 半偏相关 / 正态性 / 残差诊断 / 加权数据 / 因子变量 / 交互 / 二次项 / 功效。主文件见 stata-regression/SKILL.md。
---

# stata-regression-regression

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「多元回归 / 诊断 / 因子变量 / 交互 / 二次项 / 功效」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

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

### 因变量正态性
- OLS 假设关注的是**残差**正态，但先看因变量分布能提前发现偏态/离群值。
  ```stata
  histogram env_con, frequency normal kdensity   // 直方图 + 正态曲线 + 密度
  summarize env_con, detail                       // 偏度/峰度/分位数
  sktest env_con                                  // 正态性检验
  ```
- 严重偏态时考虑对因变量做变换（如 `ln_wage`）或换稳健方法；大样本下 `sktest` 容易显著，要结合图形判断。

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
- 书的 `aa hispanic other` 三个 race/ethnicity 哑变量不在 `nlsy97_chapter11.dta` 中，需先用
  `race97` 和 `ethnic97` 生成（书 10.5 节；`codebook race97 ethnic97` 可查编码）：
  ```stata
  use nlsy97_chapter11, clear
  generate race = race97
  replace race = 1 if race97 == 1 & ethnic97 == 0
  replace race = 2 if race97 == 2 & ethnic97 == 0
  replace race = 3 if ethnic97 == 1
  replace race = 4 if (race97 == 4 | race97 == 5) & ethnic97 == 0
  tab2 race race97 ethnic97
  recode race (2 = 1 African_American) (1 3/4 = 0 Other), generate(aa)
  recode race (3 = 1 Hispanic) (1/2 4 = 0 Other), generate(hispanic)
  recode race (4 = 1 Other_race) (1/3 = 0 W_AA_H), generate(other)
  tab1 aa hispanic other
  ```
- 检验一组系数（分类变量整体）：`test aa hispanic other`（F 检验；用上面刚生成的哑变量）。
- **分层回归前统一样本**：不同模型的观测数不能忽多忽少。`missing()` 是 Stata 函数，变量间用逗号；
  `!missing(...)` 表示"所有变量都非缺失"（`!` 是"非"）：
  ```stata
  pcorr smday97 age97 male psmoke97 ///
      if !missing(smday97, age97, male, psmoke97, aa, hispanic, other)
  ```
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
