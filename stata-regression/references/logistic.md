---
name: stata-regression-logistic
description: 逻辑回归参考：logit/logistic / OR 解读 / 假设检验 / margins 概率 / 嵌套逻辑回归 / 功效。主文件见 stata-regression/SKILL.md。
---

# stata-regression-logistic

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「逻辑回归 / OR / margins 概率」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

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
