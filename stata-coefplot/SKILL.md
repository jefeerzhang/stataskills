---
name: stata-coefplot
description: 帮助用户用 coefplot 画系数图（森林图）。Use when needing 回归系数可视化 / 多模型系数对比 / 置信区间图 / 按方程或子群分面 / 系数排序 / 矩阵结果绘图 / 边际效应图（margins post）/ OR 或标准化系数图 / 发表级系数图定制（recast bar、cismooth、headings、mlabel）。配套命令基于 Ben Jann coefplot 1.8.8，示例全部用 Stata 自带数据可复现。
---

# Stata 系数图：coefplot（森林图与模型对比图）

本 skill 整合 Ben Jann 的 `coefplot` 包（SSC）官方示例体系（getting-started + estimates / confidence-intervals / labelling / markers / varia），覆盖从基础系数图到发表级定制的完整方法。

## 运行 Stata 的方式

- 批处理（无界面）：`stata-mp -b do "脚本.do"`，结束生成同名 `.log`。平台路径见 `docs/run-stata.md`。
- **中文作图规矩**：需要图形命令且图表文字可能含中文时，先询问用户是否确需中文；默认按英文标签作图。

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

1. `margins` 必须加 `post`，否则 coefplot 画的还是原模型系数。
   **Fix**：`margins ..., post` 把边际效应存入 `e(b)` `e(V)`；否则 `coefplot` 只画原模型系数。验证：`estimates restore margins` 后 `coefplot` 应出多系数行。
2. `eform` 后参考线是 1，不是 0；`xline(0)` 在 OR 图上无意义。
   **Fix**：OR/Hazard 图用 `xline(1, lpattern(dash))`；用 `coefplot, eform` 时所有选项自动按 OR 轴解读；自检：`di exp(0)` = 1，参考线永远在 1。
3. `vertical` 后所有 `x`/`y` 选项对调（`yline(0)`、`ytitle`、`ylabel`）。
   **Fix**：默认横向（系数在 Y 轴）；`coefplot ..., vertical` 改纵向后，标题/坐标轴选项跟着对调。画前脑中过一遍：`xline` 是"垂直线"，`yline` 是"水平线"——转置后互换。
4. `bycoefs` 后 `headings()`/`groups()` 用整数编号，不是系数名。
   **Fix**：`coefplot ..., bycoefs headings(1="A" = 2="B")`；先用 `coefplot` 跑一次看系数顺序，再用整数编号。**不能写 `headings(x1="A")`**——会报 invalid numlist。
5. `byopts(xrescale)` 允许各子图不同刻度；不加时子图共用刻度，系数尺度差异大时会被压缩。
   **Fix**：系数尺度差异大（如 b1 ∈ [-0.1, 0.1]，b2 ∈ [-10, 10]）必加 `byopts(xrescale)`；否则小系数被压成一条线看不见。
6. 多模型同名系数会重叠：用 `rename()`、或 `asequation` + `swapnames` 区分。
   **Fix**：先 `estimates restore m1`，`coefplot ..., rename(_cons=mpg)`；或用 `coefplot (m1, label("Model 1")) (m2, label("Model 2"))` 分模型标注。
7. `addplot` 必须加 `norescaling`，否则会破坏 coefplot 的坐标轴。
   **Fix**：`coefplot ..., addplot((scatteri 0 1, norescaling))`；不加 `norescaling` 会把附加图层塞到与主图同坐标系，破坏 y 轴刻度。
8. 比例/百分比 CI 用 `citype(logit)`，避免置信限越界；画 bar 时用 `citop` 把 CI 放前面。
   **Fix**：百分比变量（0-100 或 0-1）置信区间易越界，加 `citype(logit)` 把 CI 计算搬到 logit 空间再映射回来；bar 图用 `recast(bar) citop` 让 CI 在柱顶而不是底部。
9. `mlabels()` 位置参数（1/11/12 等）参考 `help marker_options`；`*` 匹配所有系数。
   **Fix**：`coefplot ..., mlabels(, format(%9.3f)) mlabpos(12)` —— `mlabpos(12)` 表示标签在 12 点钟方向（上方）；`*` 匹配所有——`coefplot *, mlabels(, format(%9.2f))`。
10. `coefplot` 默认画第一个方程；多方程模型要 `keep(*:)` 或按方程号选择。
   **Fix**：`mvreg` / `sureg` 多方程，用 `coefplot ..., keep(eq1:)` 只画第一个方程；或 `keep(eq1: x1 x2)` 选特定系数。

## 详细参考（拆分阅读）

主文件保留第 1–7 章（入门）和所有陷阱速查。后续章节按常用度拆为两个 references：

| 文件 | 内容 | 何时加载时机 |
|---|---|---|
| `references/intermediate.md` | 第 8–25 章：按系数分面 bycoefs、通配符模型名、系数匹配、排序、矩阵绘图、recast、连续轴 at、eform、缩放/变换/标准化、margins/OR/CI 读法 | 入门已掌握，需多模型 + 子图 + 排序 + OR + margins 中任一能力时 |
| `references/advanced.md` | 第 26–50 章：Bootstrap CI / cismooth / 比例 CI / 标签定制 / mlabels / addplot 子图级元素 / asequation + swapnames | 常用已掌握，需 Bootstrap CI / 自定义标签 / 子图级元素 / 矩阵绘图 中任一能力时 |

拆分理由：coefplot 50 章全部塞在主 SKILL.md 里会让 Agent 上下文窗口紧张时分不清主次；按常用度分级便于分批加载（详见鲁班打磨报告 2026-08-17 P2-C）。

## 引用

> Ben Jann. 2025. coefplot: Stata module for plotting regression coefficients and other estimates. Statistical Software Components, Boston College Department of Economics. https://repec.sowi.unibe.ch/stata/coefplot/
