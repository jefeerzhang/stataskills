---
name: stata-regression-anova
description: 方差分析参考：单因素 ANOVA / ANCOVA / 双因素与交互 / 重复测量 / ICC / ANOVA 功效。主文件见 stata-regression/SKILL.md。
---

# stata-regression-anova

> **加载时机**：主 `SKILL.md` 强制路径已读完，遇到「方差分析 / ANCOVA / 重复测量 / ICC / ANOVA 功效」时加载本文件。

> **边界约定**：本文件只补详细方法签名与工作流示例。四件套陷阱统一收录在主 `SKILL.md` 的「关键陷阱速查」节；不重复陷阱条目。

---

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
- **建模前先探索分类变量 × 连续变量的关系**，用 `tabulate 分类变量, summarize(连续变量)`：
  ```stata
  use gss2006_chapter9, clear
  tabulate mobile16 if age > 29 & age < 60 & wrkstat==1, summarize(prestg80)
  tabulate age if age > 29 & age < 60 & wrkstat==1, summarize(prestg80)
  ```
- **关键：连续协变量必须加 `c.` 前缀**，否则被当作分类变量（每个取值一个 dummy，浪费自由度）。数据集 `gss2006_chapter9`：
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
