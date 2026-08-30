---
name: stata-coefplot
description: Stata coefplot 系数图（森林图）：多模型对比、置信区间、边际效应图、OR 图、发表级定制。触发词：coefplot / 森林图 / 系数图 / 置信区间 / 多模型对比 / margins 图。
compatibility: >-
  适配 Claude Code / Codex / OpenClaw / SkillsMP；StataNow 19.5 MP（macOS / Windows / Linux）实测 PASS；
  触发即读本文，无需联网加载其他文件。必装：ssc install coefplot（依赖 estout，提示时一并装）。
---

# Stata 系数图：coefplot（森林图与模型对比图）

本 skill 整合 Ben Jann 的 `coefplot` 包（SSC）官方示例体系（getting-started + estimates / confidence-intervals / labelling / markers / varia），覆盖从基础系数图到发表级定制的完整方法。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

## 强制路径

匹配到第一条就停。第 1–7 章见下文；更细语法见 `references/`；禁令见文末黑名单。

**何时用**：已经估完模型，要画系数图 / 森林图 / 多模型对比。
**何时踢走**：还没回归 → 先 `stata-regression`；还没 DID → 先 `stata-did`。本 skill 只画图，不改识别策略。

多模型森林图：

```stata
quietly regress y x1 x2
estimates store m1
quietly regress y x1 x2 x3
estimates store m2
coefplot m1 m2, drop(_cons) xline(0)
```

OR / 风险比图把 `xline(0)` 换成 `xline(1)`，并加 `eform`。`margins` 图必须先 `margins ..., post`。`bycoefs` 的 `headings()` 用整数编号，不用系数名。

## 安装与版本

```stata
ssc install coefplot, replace    // 依赖 ssc install estout 等，coefplot 会自动提示
which coefplot                   // 查版本（本仓库验证环境：1.8.8 22aug2025）
```

## 核心概念

- `coefplot` 从估计结果的 `e(b)`（点估计）与 `e(V)`（方差）读取系数和 CI，画水平布局的系数图；`vertical` 翻转。
- 四种选项层级：**modelopts**（单个模型）⊂ **plotopts**（单个系列）⊂ **subgropts**（单个子图）⊂ **globalopts**（整图）。上层可放下层选项作为默认，下层覆盖上层。
- 三个容器语法：`(模型, 选项)` 一个系列；`\` 在同一括号内合并多个模型；`||` 分隔子图。

---

## 0. estout/esttab 工作流衔接

实际研究中常用 `eststo`/`estout` 管理模型，再喂给 coefplot：

```stata
ssc install estout  // 首次使用

sysuse auto, clear
eststo clear

eststo m1: regress price mpg
eststo m2: regress price mpg trunk
eststo m3: regress price mpg trunk length

* 先用 esttab 看表格
esttab, se star(* 0.1 ** 0.05 *** 0.01)

* 再用 coefplot 作图（eststo 存储的模型直接用名字调用）
coefplot m1 m2 m3, drop(_cons) xline(0)
```

**关键点**：
- `eststo` 存储的模型名可以直接用于 `coefplot`，无需额外 `estimates store`
- `estadd` 可添加自定义统计量到已存储的模型，`coefplot` 通过 `matrix()` 读取
- `estimates dir` 查看已存储的模型列表

---

# 第一部分 基本用法（getting-started）

## 1. 基本用法

语法：`coefplot [name] [, options]`，其中 `name` 是已存储模型名（见 `help estimates store`），`.` 或空串表示当前模型。

```stata
sysuse auto, clear
regress price mpg trunk length turn
coefplot, drop(_cons) xline(0)          // 剔除常数项，零点参考线
coefplot, vertical drop(_cons) yline(0) // 垂直版：参考线改用 yline
```

- 默认画第一个方程的全部系数；`_cons` 通常被 `drop(_cons)` 剔除。
- 系数名在分类轴上；水平布局用 `xline(0)`，垂直布局用 `yline(0)`。

## 2. keep 和 drop

```stata
sysuse auto, clear
gen mpp = mpg/8
mlogit rep78 mpp i.foreign if rep78>=3
coefplot, nolabel drop(_cons) keep(*:) omitted baselevels   // 所有方程 + 省略/基准类
coefplot, nolabel keep(3:*.foreign 4:mpp 5:mpp _cons) omitted baselevels
```

- `keep()` / `drop()` 按名称选择；`keep(*:)` 选所有方程。
- `omitted` / `baselevels` 把被省略和基准类的 0 系数也画出来。
- `keep(3:*.foreign 4:mpp ...)` 按方程号分别选系数。

## 3. 多模型多系列

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store D
regress price mpg trunk length turn if foreign==1
estimates store F
coefplot D F, drop(_cons) xline(0)
coefplot (D, label(Domestic Cars) pstyle(p3)) ///
    (F, label(Foreign Cars) pstyle(p4)) ///
    , drop(_cons) xline(0) msymbol(S)
coefplot D F, drop(_cons) xline(0) msymbol(S) ///
    p1(label(Domestic Cars) pstyle(p3))       ///
    p2(label(Foreign Cars)  pstyle(p4))
```

- `(模型, 系列选项)` 单独设置每个系列；`p1() p2()` 也可按位置设置系列选项。
- 全局选项对全部系列生效；系列内选项优先。

## 4. 改变偏移

```stata
coefplot (D, offset(0.05)) (F, offset(-0.05)), drop(_cons) xline(0)
coefplot D F, drop(_cons) xline(0) nooffsets   // 关闭自动偏移
```

- 自动偏移防止 CI 重叠；`offset(±0.05)` 自定义偏移；系数间距为 1，通常取 ±0.5 以内。

## 5. 多轴

```stata
sysuse auto, clear
regress price mpg trunk length turn
estimates store Price
regress weight mpg trunk length turn
estimates store Weight
coefplot Price (Weight, axis(2)), drop(_cons) xtitle(Price) xtitle(Weight, axis(2))
```

- 结果尺度不同时用 `axis(2)` 给第二个模型独立坐标轴。

## 6. 合并模型到同一系列

```stata
sysuse auto, clear
regress price mpg trunk length turn
estimates store multivariate
foreach var in mpg trunk length turn {
    quietly regress price `var'
    estimates store `var'
}
coefplot (mpg trunk length turn, label(bivariate)) ///
    (multivariate) ///
    , drop(_cons) xline(0)
```

- 括号内多个模型合并为一个系列；同名系数会重叠，可用 `rename()` 改名或见第 49 节 `asequation` + `swapnames`。

## 7. 子图

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store D
regress price mpg trunk length turn if foreign==1
estimates store F
coefplot D, bylabel(Domestic Cars) ///
    || F, bylabel(Foreign Cars) ///
    ||, drop(_cons) xline(0)
```

- `||` 分隔子图；`bylabel()` 子图标题；`byopts(xrescale)` 允许各子图不同尺度。
- `byopts(compact cols(1))` 控制排列；子图标题按 subtitle 样式，可用 `subtitle()` 调样式。
- `_skip` 作空位对齐子图；`norecycle` 让每个子图使用各自 pstyle，而不是每子图重新开始。

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store D
regress price mpg trunk length turn if foreign==1
estimates store F
regress weight mpg trunk length turn if foreign==0
estimates store D_weight
regress weight mpg trunk length turn if foreign==1
estimates store F_weight
coefplot (D, label(Domestic)) (F, label(Foreign)), bylabel(Price) ///
    || (D_weight)           (F_weight)         , bylabel(Weight)  ///
    ||, drop(_cons) xline(0) byopts(xrescale)
coefplot (D, label(Domestic)) (F, label(Foreign)), bylabel(Price) ///
    || _skip                (F_weight)         , bylabel(Weight)  ///
    ||, drop(_cons) xline(0) byopts(xrescale)
```

```stata
coefplot D, bylabel(Domestic Cars) || F, bylabel(Foreign Cars) ///
    ||, drop(_cons) xline(0) byopts(compact cols(1))
coefplot D, bylabel(Domestic Cars) || F, bylabel(Foreign Cars) ///
    ||, drop(_cons) xline(0) byopts(compact cols(1)) ///
    subtitle(, size(vlarge) margin(medium) justification(left) ///
        color(white) bcolor(black) bmargin(top_bottom))
```

```stata
coefplot (rep2, label(rep78=2)) (rep3, label(rep78=3)), bylabel(Low record) ///
    || (rep4, label(rep78=4)) (rep5, label(rep78=5)), bylabel(High record) ///
    ||, drop(_cons) xline(0) norecycle legend(colfirst)
```

## 关键陷阱速查

> 统一格式：**陷阱 → 触发 → Fix → 验证** 四件套。每条陷阱都给出可执行的修复 + 验证；Agent 在 SKILL.md 读到警告时即拿到完整修复路径。

1. `margins` 必须加 `post`，否则 coefplot 画的还是原模型系数
   - **触发**：跑 `margins, dydx(x)` 后 `coefplot` 出图，发现画的是 `regress` 原系数而非边际效应——因为 margins 未存入 `e(b)`。
   - **Fix**：`margins ..., post` 把边际效应存入 `e(b)` `e(V)`；否则 `coefplot` 只画原模型系数。验证：`estimates restore margins` 后 `coefplot` 应出多系数行。
   - **验证**：`estimates restore margins` → `coefplot, drop(_cons)` 应出边际效应图；不加 `post` 出原模型系数。

2. `eform` 后参考线是 1，不是 0；`xline(0)` 在 OR 图上无意义
   - **触发**：跑 `logit y x, or` 后 `coefplot, eform xline(0)` 出图，参考线在 OR = 1 之外，导致解读错误。
   - **Fix**：OR/Hazard 图用 `xline(1, lpattern(dash))`；用 `coefplot, eform` 时所有选项自动按 OR 轴解读；自检：`di exp(0)` = 1，参考线永远在 1。
   - **验证**：`coefplot, eform xline(1)` 应在 OR = 1 处画线；`xline(0)` 在 eform 图上无意义。

3. `vertical` 后所有 `x`/`y` 选项对调
   - **触发**：跑 `coefplot ..., vertical` 后用 `xline(0)`，但实际应在 `yline(0)`——转置后选项语义对调。
   - **Fix**：默认横向（系数在 Y 轴）；`coefplot ..., vertical` 改纵向后，标题/坐标轴选项跟着对调。画前脑中过一遍：`xline` 是"垂直线"，`yline` 是"水平线"——转置后互换。
   - **验证**：`coefplot, vertical` + `yline(0)` 应在系数 = 0 处画水平线；用 `xline(0)` 无效果。

4. `bycoefs` 后 `headings()`/`groups()` 用整数编号，不是系数名
   - **触发**：写 `coefplot ..., bycoefs headings(x1="A")` 报 `invalid numlist`（headings() 只接受整数编号）。
   - **Fix**：`coefplot ..., bycoefs headings(1="A" = 2="B")`；先用 `coefplot` 跑一次看系数顺序，再用整数编号。**不能写 `headings(x1="A")`**——会报 invalid numlist。
   - **验证**：跑 `coefplot` 一次看 `e(b)` 输出顺序；按顺序用整数 1, 2, 3... 写 headings。

5. `byopts(xrescale)` 允许各子图不同刻度
   - **触发**：多模型嵌套回归（系数尺度差异大）跑 `coefplot m1 m2 m3, bycoefs`，但 b1 ∈ [-0.1, 0.1]、b2 ∈ [-10, 10]——小系数被压成一条线。
   - **Fix**：系数尺度差异大（如 b1 ∈ [-0.1, 0.1]，b2 ∈ [-10, 10]）必加 `byopts(xrescale)`；否则小系数被压成一条线看不见。
   - **验证**：`coefplot, bycoefs byopts(xrescale)` 应让各子图独立刻度；不加则小系数不可见。

6. 多模型同名系数会重叠：用 `rename()`、或 `asequation` + `swapnames` 区分
   - **触发**：跑两个模型都有 `_cons`，画森林图时 `_cons` 重叠，分不清哪个模型的常数项。
   - **Fix**：先 `estimates restore m1`，`coefplot ..., rename(_cons=mpg)`；或用 `coefplot (m1, label("Model 1")) (m2, label("Model 2"))` 分模型标注。
   - **验证**：图例应区分每个模型的常数项；无区分 = 重叠不可读。

7. `addplot` 必须加 `norescaling`，否则会破坏 coefplot 的坐标轴
   - **触发**：跑 `coefplot, addplot((scatteri 0 1))` 不加 `norescaling`，附加图层破坏 y 轴刻度。
   - **Fix**：`coefplot ..., addplot((scatteri 0 1, norescaling))`；不加 `norescaling` 会把附加图层塞到与主图同坐标系，破坏 y 轴刻度。
   - **验证**：附加图层应使用独立坐标系；不加 `norescaling` 报 y 轴错乱。

8. 比例/百分比 CI 用 `citype(logit)`，避免置信限越界
   - **触发**：跑 `proportion var` 后 `coefplot` 画 CI，但 95% CI 可能跨越 [0,1] 边界（如 [−0.05, 0.35]），不合理。
   - **Fix**：百分比变量（0-100 或 0-1）置信区间易越界，加 `citype(logit)` 把 CI 计算搬到 logit 空间再映射回来；bar 图用 `recast(bar) citop` 让 CI 在柱顶而不是底部。
   - **验证**：`coefplot, citype(logit)` CI 应在 [0, 1] 内；不加可能越界。

9. `mlabels()` 位置参数（1/11/12 等）参考 `help marker_options`；`*` 匹配所有系数
   - **触发**：写 `coefplot, mlabels()` 报 `mlabels() invalid`；或位置参数用错方向（如想让标签在右但用了 `mlabpos(6)`）。
   - **Fix**：`coefplot ..., mlabels(, format(%9.3f)) mlabpos(12)` —— `mlabpos(12)` 表示标签在 12 点钟方向（上方）；`*` 匹配所有——`coefplot *, mlabels(, format(%9.2f))`。
   - **验证**：`mlabpos(12)` 应让标签在系数点上方；位置参数参考 `help marker_options` 的时钟方向图。

10. `coefplot` 默认画第一个方程；多方程模型要 `keep(*:)` 或按方程号选择
    - **触发**：跑 `mvreg` / `sureg` 多方程模型后 `coefplot` 出图，只画第一个方程的系数；其他方程被静默忽略。
    - **Fix**：`mvreg` / `sureg` 多方程，用 `coefplot ..., keep(eq1:)` 只画第一个方程；或 `keep(eq1: x1 x2)` 选特定系数。
    - **验证**：`coefplot, keep(eq1: eq2:)` 应画出所有方程；无 `keep` 默认只画第一个。

## 详细参考（拆分阅读）

主文件保留第 1–7 章（入门）和所有陷阱速查。后续章节按常用度拆为两个 references：

| 文件 | 内容 | 何时加载时机 |
|---|---|---|
| `references/intermediate.md` | 第 8–25 章：按系数分面 bycoefs、通配符模型名、系数匹配、排序、矩阵绘图、recast、连续轴 at、eform、缩放/变换/标准化、margins/OR/CI 读法 | 入门已掌握，需多模型 + 子图 + 排序 + OR + margins 中任一能力时 |
| `references/advanced.md` | 第 26–50 章：Bootstrap CI / cismooth / 比例 CI / 标签定制 / mlabels / addplot 子图级元素 / asequation + swapnames | 常用已掌握，需 Bootstrap CI / 自定义标签 / 子图级元素 / 矩阵绘图 中任一能力时 |

拆分理由：coefplot 50 章全部塞在主 SKILL.md 里会让 Agent 上下文窗口紧张时分不清主次；按常用度分级便于分批加载。

## ❌ Agent 不该做的事（黑名单）

> 与 ADR-0001 联动：本节是「**主动反模式**」清单——「关键陷阱速查」是被动警告，本节是主动规范。Agent 在画图前必查一遍。

- ❌ **不要在 `margins` 后不加 `post` 跑 coefplot**：画的是原模型系数而非边际效应。**替代**：`margins ..., post` 把边际效应存入 `e(b)` `e(V)`；跑完 `estimates restore margins` → `coefplot`。
- ❌ **不要在 OR 图上用 `xline(0)`**：OR 轴的参考线应在 1。**替代**：OR/Hazard 图用 `xline(1, lpattern(dash))`；自检 `display exp(0)` = 1。
- ❌ **不要在 `vertical` 后用 `xline` 不改 `yline`**：选项语义对调。**替代**：`coefplot ..., vertical` 后 `xline` ↔ `yline`、`xtitle` ↔ `ytitle`、`xlabel` ↔ `ylabel`。
- ❌ **不要在 `bycoefs` 后用 `headings(x1="A")`**：报 `invalid numlist`。**替代**：用整数编号 `headings(1="A" 2="B" 3="C")`；先 `coefplot` 跑一次看 `e(b)` 顺序。
- ❌ **不要在尺度差异大的多模型上不加 `byopts(xrescale)`**：小系数被压成一条线看不见。**替代**：b1 ∈ [-0.1, 0.1]、b2 ∈ [-10, 10] 时必加 `byopts(xrescale)`。
- ❌ **不要在 `addplot` 时不加 `norescaling`**：破坏主图坐标系。**替代**：必加 `addplot((scatteri 0 1, norescaling))`。
- ❌ **不要在 mvreg / sureg 多方程模型不写 `keep(eq1:)`**：默认只画第一个方程，其他方程被静默忽略。**替代**：`coefplot ..., keep(eq1: eq2:)` 或 `keep(eq1: x1 x2)`。
- ❌ **不要对比例变量不加 `citype(logit)`**：CI 越界（如 [-0.05, 0.35]）。**替代**：百分比变量加 `citype(logit)`；bar 图加 `recast(bar) citop`。
- ❌ **不要画 50+ 系数散点图不加排序/分组**：图不可读。**替代**：先 `coefplot, sort(coefficient) drop(_cons) bycoefs`；或按分组 `headings()` 折叠。

## 🔍 错误码速查（错误码 → 触发 → 修复）

> 与上方「❌ Agent 不该做的事（黑名单）」互补：黑名单给原则，错误码给精准命中。Agent 看到 r(N) 时直接查本节定位。

- **`r(198)`** — coefplot 报 not estimable（模型无对应系数）。**修复**：keep(*:) 全选；matrix list e(b) 看实际有系数的项
- **`r(303)`** — margins/post 后 coefplot 报 conformability。**修复**：margins 跑完必 estimates restore margins；否则 coefplot 看的是原模型
- **`r(7)`** — bycoefs headings(x1=A) 报 invalid numlist。**修复**：headings() 只接整数：headings(1=A 2=B)；先 coefplot 跑一次看 e(b) 顺序

## 引用

> Ben Jann. 2025. coefplot: Stata module for plotting regression coefficients and other estimates. Statistical Software Components, Boston College Department of Economics. https://repec.sowi.unibe.ch/stata/coefplot/

## ✅ 交付前自检清单（跑完命令后逐条核对）

- [ ] `margins` 图已加 `post`（否则画的是原模型系数）；`estimates restore` 后验证
- [ ] OR/Hazard 图 `eform` + `xline(1)`；未在 OR 图上误用 `xline(0)`
- [ ] `vertical` 后 `xline`↔`yline`、`xtitle`↔`ytitle` 已对调
- [ ] `bycoefs` 的 `headings()` 用整数编号（先跑一次看 `e(b)` 顺序），未用系数名
- [ ] 多模型尺度差异大已加 `byopts(xrescale)`；同名系数已 `rename()` 或分模型 label
- [ ] `addplot` 已加 `norescaling`；多方程模型已 `keep(eq1: eq2:)`
- [ ] 比例变量 CI 已 `citype(logit)`；图已导出 PNG 且文件存在（中文标签前已与用户确认，默认英文）
