---
name: stata-coefplot-advanced
description: coefplot 进阶功能参考（Ben Jann 手册第 26–50 章对应内容）。覆盖 Bootstrap CIs、平滑 CIs cismooth、比例的 CI、截断置信区间、标签 vs 名称、自定义标签 coeflabels、标题和分组 headings/groups、bycoefs 下的 headings/groups、方程标签 eqlabels、对侧标签 yscale(alt)、左对齐标签、网格线 grid、标记样式、只要标记/只要 CI、标记标签（点估计值）、字符串表达式与 @ 变量、自定义标签 mlabels、CI 末端标签（addplot 变通）、标记标签作为轴标签（程序变通）、加权标记 weight、箭头表示变化、条形图、addplot 命令（子图级元素）、子图不同大小、模型名作为系数名（asequation + swapnames）。主文件见 `stata-coefplot/SKILL.md`；常用功能见 `stata-coefplot/references/intermediate.md`。
---

# stata-coefplot 进阶功能（第 26–50 章）

> **加载时机**：主 `SKILL.md`（1–7 章入门）+ `references/intermediate.md`（8–25 章常用）已读完，遇到"Bootstrap CI / cismooth / 比例 CI / 标签定制 / mlabels / addplot 子图级元素 / 矩阵绘图"中任一需求时加载本文件。本文件对应 Ben Jann coefplot 手册里较少用但功能强大的后段。
>
> **本文件不重复主文件与 intermediate.md 的内容**——只补 26–50 章的具体语法。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节。

---

## 26. Bootstrap CIs

```stata
sysuse auto, clear
regress price mpg trunk length turn, vce(bootstrap)
coefplot (., ci(ci_normal) label(normal)) ///
    (., ci(ci_percentile) label(percentile)) ///
    (., ci(ci_bc) label(bc)) ///
    , drop(_cons) xline(0) legend(rows(1))
```

## 27. 平滑 CIs cismooth

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store domestic
regress price mpg trunk length turn if foreign==1
estimates store foreign
coefplot domestic foreign, drop(_cons) xline(0) cismooth grid(none)
```

- `cismooth` 自动生成 50 层渐变 CI；不受 `levels()`/`ci()`/`ciopts()` 影响；若同时指定，平滑 CI 在底层。

## 28. 比例的 CI

```stata
sysuse auto, clear
proportion rep78 if foreign==0
estimates store domestic
proportion rep78 if foreign==1
estimates store foreign
coefplot domestic foreign, xtitle(Repair Record 1978) ytitle(Proportion) ///
    vertical recast(bar) barwidth(0.25) finten(60) ///
    citop citype(logit) ciopts(recast(rcap)) rename(*.rep78 = "")
```

- `citype(logit)` 让比例 CI 在 0–1 内；`rename(*.rep78 = "")` 清理 `proportion` 的系数命名。

## 29. 截断置信区间

```stata
sysuse nlsw88, clear
regress wage ibn.occupation, nocons
coefplot, transform(* = min(max(@,1.5),12.5)) ///
    xscale(range(1.5 12.5)) plotregion(margin(zero))
```

- 宽 CI 可截断以突出主要信息；截断后要让 spike 到图边缘（`plotregion(margin(zero))`）。
- 更精细的做法是用 `if()` 对截断/未截断系数分配不同 `ciopts(recast(pcarrow/pcrarrow/pcbarrow))`。

```stata
coefplot, transform(* = min(max(@,2),12)) ///
    plotregion(color(gray) icolor(white)) grid(nogextend)
```

```stata
coefplot (., pstyle(p1) if(@ll>2&@ul<12)) ///
    (., pstyle(p1) if(@ll>2&@ul>=12)  ciopts(recast(pcarrow)))  ///
    (., pstyle(p1) if(@ll<=2&@ul<12)  ciopts(recast(pcrarrow))) ///
    (., pstyle(p1) if(@ll<=2&@ul>=12) ciopts(recast(pcbarrow))) ///
    , nooffset transform(* = min(max(@,2),12)) legend(off)
```

---

# 第四部分 标签（Examples / Labelling）

## 30. 标签 vs 名称

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0)                      // 默认用变量标签/值标签
coefplot, xline(0) nolabels             // 用原始系数名
regress, coeflegend noheader            // 查看系数名的精确写法
```

## 31. 自定义标签 coeflabels

```stata
coefplot, xline(0) coeflabels(1.foreign = "Foreign Car" _cons = "Constant")
coefplot, xline(0) coeflabels(, wrap(20))                        // 长标签换行
coefplot, xline(0) coeflabels(4.rep78 = `""Repair Record" "1978 = 4""', wrap(20))
coefplot, xline(0) coeflabels(, interaction(" x "))              // 交互符号
```

- `wrap()` 换行、`truncate()` 截断、`interaction()` 改变交互连接符。

## 32. 标题和分组 headings / groups

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0) omitted baselevels drop(_cons) ///
    headings(3.rep78 = "{bf:Repair Record}" ///
        0.foreign = "{bf:Car Type}" ///
        3.rep78#0.foreign = "{bf:Interaction Effects}")
```

- `headings()` 在系数间插标题；`groups()` 给系数分组并加分组标签；两者可组合；`nogap` 去掉标题前空隙。
- 可用 `{bf:}` 加粗、`{it:}` 斜体（见 `help text`）。

## 33. bycoefs 下的 headings/groups

```stata
sysuse auto, clear
regress price mpg headroom weight turn
estimates store Total
regress price mpg headroom weight turn if foreign==0
estimates store Domestic
regress price mpg headroom weight turn if foreign==1
estimates store Foreign
coefplot Domestic || Foreign || Total, drop(_cons) yline(0) ///
    bycoefs byopts(yrescale) vertical ///
    groups(1 2 = "{bf:Subgroup results}", nogap) ylabel(0, add)
```

- `bycoefs` 后分类轴用整数编号（1, 2, ...），所以 `headings()`/`groups()` 里用数字而非系数名。

## 34. 方程标签 eqlabels

```stata
sysuse auto, clear
gen mpp = mpg/8
mlogit rep78 mpp i.foreign if rep78>=3
coefplot, omitted keep(*:) coeflabels(mpp = "Milage") ///
    eqlabels("Equation 1" "Equation 2" "Equation 3")
coefplot, omitted keep(*:) coeflabels(mpp = "Milage") ///
    eqlabels("{bf:Equation 1}" "{bf:Equation 2}" "{bf:Equation 3}", asheadings)
```

- `eqlabels(..., asheadings)` 把方程标签放在各方程开头（此时不能用 `headings()`）。
- `eqlabels(, labels)` 把方程名当作变量名去取变量标签。

## 35. 对侧标签 yscale(alt)

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0) omitted baselevels drop(_cons) yscale(alt) ///
    headings(3.rep78 = "{bf:Repair Record}" ///
        0.foreign = "{bf:Car Type}" ///
        3.rep78#0.foreign = "{bf:Interaction Effects}")
```

- `yscale(alt)` 把系数标签移到右侧；分组/方程标签要加 `axis()` 子选项，如 `yscale(alt axis(2))`。

## 36. 左对齐标签

```stata
coefplot, xline(0) drop(_cons) omitted baselevels yscale(noline alt) ///
    graphregion(margin(l=65)) coeflabels(, notick labgap(-125)) ///
    headings(3.rep78 = "{bf:Repair Record}" 0.foreign = "{bf:Car Type}" ///
        3.rep78#0.foreign = "{bf:Interaction Effects}", labgap(-130))
```

- 左侧标签默认右对齐；把标签移到右侧再用负 `labgap` 拉到左边实现左对齐。可配合 `gr_edit .move yaxis1 leftof 8 5` 微调。

## 37. 网格线 grid

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0) xlabel(, grid) ///
    grid(between glpattern(dash) glwidth(*2) glcolor(gray))
coefplot, xline(0) ytick(1.5 3.5 4.5 6.5, notick glstyle(refline))
```

- `grid()` 控制系数间网格线；`ytick()`/`xtick()` 手工定义网格位置。

---

# 第五部分 标记（Examples / Markers）

## 38. 标记样式

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep i.foreign
estimates store m1
regress mpg headroom i.rep##i.foreign
estimates store m2
coefplot (m1, msymbol(D) mlcolor(magenta) mfcolor(magenta*.3)) ///
    (m2, msymbol(S)) ///
    , mfcolor(white) msize(large)
```

- 标记样式遵循 `marker_options`；`pstyle()` 一次换整套标记+CI 样式；`ciopts(pstyle())` 只换 CI 样式。

## 39. 只要标记 / 只要 CI

```stata
sysuse auto, clear
regress price mpg trunk length turn
coefplot (., noci label(Markers only)) ///
    (., cionly label(CIs only) key(ci)) ///
    , drop(_cons)
```

- `noci` 不画 CI；`cionly` 只画 CI。`cionly` 系列不出现在图例，需要 `key(ci)` 生成图例。

## 40. 标记标签（点估计值）

```stata
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0) mlabel format(%9.2g) mlabposition(12) mlabgap(*2)
```

- `mlabel` 显示点估计值；`format()` 设置格式；`mlabposition()` 标签位置（0=居中）。

## 41. 字符串表达式与 @ 变量

```stata
coefplot, xline(0) mlabposition(1) mlabgap(*2) ///
    mlabel("{it:p} = " + string(@pval,"%9.3f"))
coefplot, xline(0) mlabposition(1) ///
    mlabel(cond(@pval<.001, "***", cond(@pval<.01, "**", ///
        cond(@pval<.05, "*", cond(@pval<.1, "+", ""))))) ///
    note("+ p < .1, * p < .05, ** p < .01, *** p < .001")
```

- `mlabel()` 内可用字符串表达式；`@pval` 是 p 值临时变量。

## 42. 自定义标签 mlabels

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store domestic
regress price mpg trunk length turn if foreign==1
estimates store foreign
coefplot (domestic, mlabels(length = 1 "+" * = 11 "0")) ///
    (foreign, mlabels(trunk length = 1 "+" * = 11 "0")) ///
    , drop(_cons) xline(0) note("Hypotheses: + positive effect; 0 no effect")
```

- `mlabels(系数 = 位置 "标签" ...)` 给指定系数的指定系列加标签；`*` 匹配所有系数。

## 43. CI 末端的标签（addplot 变通）

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store domestic
regress price mpg trunk length turn if foreign==1
estimates store foreign
coefplot domestic foreign, drop(_cons) xline(0) ///
    addplot(scatter @at @ul, ms(i) mlabel(@b) mlabformat("%9.1f") ///
        mlabcolor(black) mlabpos(2))
```

- `addplot()` 用内部临时变量（`@at` 位置、`@ul` CI 上界、`@b` 估计值）把标签放到 CI 末端。
- 复杂标签可先 `mlabel(...) mlabcolor(none)` 生成 `@mlbl`，再在 `addplot()` 中使用。

## 44. 标记标签作为轴标签（程序变通）

- 需要写一个小程序（`coefplot_mlbl`）调用 `coefplot, generate replace nodraw` 收集标签，再用 `ymlabel(..., axis(2))` 放到右侧轴。核心思路：
  1. `qui coefplot ..., generate replace nodraw` 生成内部变量 `__at`（位置）和 `__mlbl`（标签）；
  2. 用 Mata 把位置和标签拼成 `s(mlbl)`；
  3. 重画图时 ``ymlabel(`s(mlbl)', angle(0) notick axis(2))``。
- 该变通适合把估计值作为右侧轴标签的发表级图；实现代码见 coefplot 官方 markers 页。

## 45. 加权标记 weight()

```stata
sysuse auto, clear
regress price mpg trunk length turn
coefplot, weight(1/@se) ms(oh) drop(_cons) xline(0)
```

- `weight(表达式)` 缩放标记大小；`@se` 是标准误临时变量；`aux(_N)` 可引入额外向量（如 `mean` 的组样本量 `e(_N)`）后用 `@aux1`。

---

# 第六部分 其他（Examples / Varia）

## 46. 箭头表示变化

```stata
webuse nlswork, clear
mean ln_wage if year==88, over(ind_code)
matrix b88 = e(b)
mean ln_wage if year==78, over(ind_code)
mata: assert(st_matrixcolstripe("b88")==st_matrixcolstripe("e(b)"))
quietly estadd matrix b88
coefplot, ci((b b) (b b88)) ciopts(recast(rcap pcarrow)) cionly ///
    vertical sort rename(^.+@([0-9]+)\..+$ = \1, regex) ///
    xtitle("Industry code") ytitle("Change in ln(wage) from 78 to 88")
```

- 用两个 CI（零宽度 `(b b)` + 目标 `(b b88)`）配合 `recast(rcap pcarrow)` 画“起点帽 + 变化箭头”。

## 47. 条形图

```stata
sysuse auto, clear
proportion rep78 if foreign==0
estimates store domestic
proportion rep78 if foreign==1
estimates store foreign
coefplot domestic foreign, vertical recast(bar) barwidth(0.3) fcolor(*.5) ///
    ciopts(recast(rcap)) citop citype(logit) format(%9.2f) ///
    addplot(scatter @b @at, ms(i) mlabel(@b) mlabpos(2) mlabcolor(black))
```

- 条形图常用 `vertical recast(bar)`；每个条形不同样式时把每个系数拆成单独系列，再 `nooffsets`。
- 堆叠条形图需 `moremata` 构造累计矩阵，再用 `ciopts(recast(rbar))`；实现见官方 varia 页。

## 48. addplot 命令（子图级元素）

```stata
sysuse auto, clear
logit foreign mpg trunk length turn
coefplot ., bylabel(Log odds) || ., bylabel(Odds ratios) eform ///
    || , drop(_cons) nolabel byopts(xrescale)
addplot 1: , xline(0) norescaling
addplot 2: , xline(1) norescaling
```

- `addplot`（`ssc install addplot`）可给指定子图添加 `xline()`、`b1title()`、独立图例等；**必须加 `norescaling`** 防止坐标轴被重新缩放。
- 子图独立图例：`addplot 1: , legend(order(2 "rep78=2" 4 "rep78=3") on) norescaling`（注意 CI spike 也占图例键，序号要数进去）。

## 49. 子图不同大小

```stata
sysuse auto, clear
regress price mpg trunk length turn
estimates store price
regress weight mpg trunk length turn
estimates store weight
coefplot price, drop(_cons) subtitle(Price, box bexpand lstyle(none)) ///
    name(price) nodraw
coefplot weight, drop(_cons) subtitle(Weight, box bexpand lstyle(none)) ///
    name(weight) nodraw yscale(off) fxsize(40)
graph combine price weight, imargin(small)
graph drop price weight
```

- 子图大小不同需分别 `nodraw` 生成，再用 `graph combine` 合并；`fxsize()` 控制子图宽度比例。

## 50. 模型名作为系数名（asequation + swapnames）

```stata
sysuse nlsw88, clear
foreach i in 4 6 7 11 12 {
    quietly regress wage grade ttl_exp tenure if industry==`i'
    estimates store industry_`i'
}
coefplot (industry_*), keep(grade) asequation swapnames ///
    title("Effect of grade on wages by industry")
```

- 同一系数名来自多个模型时，用 `asequation` 把模型名变成方程名，`swapnames` 交换方程名与系数名，模型名就成了系数名。
- 要改成值标签可 `eqrename(^industry_(.*)$ = \1.industry, regex)`。

---

## 内部临时变量速查

| 变量 | 含义 |
|---|---|
| `@b` | 点估计 |
| `@ll` / `@ul` | CI 下限 / 上限 |
| `@se` | 标准误 |
| `@pval` | p 值 |
| `@at` | 系数在分类轴上的位置 |
| `@plot` | 系列编号 |
| `@mlbl` | 由 `mlabel()` 生成的标签变量 |

