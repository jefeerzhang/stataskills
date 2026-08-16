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

## 8. 按系数分面 bycoefs

```stata
sysuse auto, clear
forvalues i = 3/5 {
    quietly regress price mpg headroom weight turn if rep78==`i'
    estimates store rep78_`i'
}
coefplot rep78_3 || rep78_4 || rep78_5, drop(_cons) xline(0) ///
    bycoefs byopts(xrescale)
coefplot rep78_3 || rep78_4 || rep78_5, drop(_cons) yline(0) ///
    bycoefs byopts(yrescale) vertical
```

- `bycoefs` 把“系数”和“子图”互换：每个系数一个子图，每个模型成为一个“系数”。
- 子图标题用 `bylabel()`；系列标签可用 `plotlabels()`。

```stata
sysuse auto, clear
forv s = 0/1 {
    forv i = 3/5 {
        quietly mean price mpg headroom weight if foreign==`s' & rep78==`i'
        estimate store m`s'_`i'
    }
}
coefplot m0_3 m1_3, bylabel(rep78=3) ///
    || m0_4 m1_4, bylabel(rep78=4) ///
    || m0_5 m1_5, bylabel(rep78=5) ///
    || , bycoefs byopts(xrescale) ///
         plotlabels("Domestic cars" "Foreign cars")
```

## 9. 通配符模型名

```stata
sysuse auto, clear
foreach var of varlist mpg trunk length turn {
    quietly regress price `var' if foreign==0
    estimates store d_`var'
    quietly regress price `var' if foreign==1
    estimates store f_`var'
}
coefplot (d*, label(domestic)) (f*, label(foreign)) ///
    , drop(_cons) xline(0) title("Bivariate effects on price by car type")
```

- `*` 任意字符串，`?` 任意单个字符。括号内 `d*` 合并为同一系列；不加括号 `d*` 会展开为多个系列。
- 展开为多个系列时用 `p1() p2()` 给各系列单独选项；系列标签可用 `plotlabels()`，子图标签可用 `bylabels()`。

```stata
coefplot (d*, asequation(Domestic) \ f*, asequation(Foreign) \ , pstyle(p4)) ///
    , drop(_cons) xline(0) title("Bivariate effects on price by car type")
```

```stata
sysuse nlsw88, clear
generate lnwage = ln(wage)
forvalues i=0/1 {
    forvalues j=1/2 {
        quietly regress lnwage grade ttl_exp tenure if south==`i' & race==`j'
        estimates store est`i'_`j'
    }
}
coefplot est0* || est1*, drop(_cons) xline(0) ///
    plotlabels("White" "Black") bylabels("North" "South")
```

```stata
sysuse auto, clear
forvalues i=3/5 {
    quietly regress price mpg trunk if rep78==`i'
    estimates store rep_`i'
}
coefplot rep*, drop(_cons) xline(0) ///
    p1(pstyle(p3) label("Rep=3")) ///
    p2(pstyle(p4) label("Rep=4")) ///
    p3(pstyle(p5) label("Rep=5"))
```

## 10. 系数匹配

- 默认按系数名匹配，忽略方程名。`eqstrict` 严格按方程名匹配；`keep(*:)` 包含所有方程。
- `asequation(名称)` / `eqrename(旧 = 新)` 调整方程名；`noeqlabels` 去掉方程标签。
- `rename()` 修改系数名；`transform()` 变换系数（`@` 为占位符）。

```stata
webuse laborsub, clear
regress whrs kl6 k618 wa we
estimates store regress
tobit whrs kl6 k618 wa we, ll(0)
estimates store tobit
coefplot regress tobit, xline(0)                              // 默认只匹配同名系数
coefplot regress tobit, xline(0) eqstrict
coefplot regress tobit, xline(0) keep(*:) ///
    transform(var(e.whrs) = sqrt(@)) rename(var(e.whrs) = Sigma)
coefplot (regress, asequation(whrs)) ///
    (tobit, keep(*:) transform(var(e.whrs) = sqrt(@)) ///
        rename(var(e.whrs) = Sigma)) ///
    , xline(0)
coefplot (regress, asequation(whrs)) ///
    (tobit, keep(*:) transform(var(e.whrs) = sqrt(@)) ///
        rename(var(e.whrs) = Sigma)) ///
    , xline(0) noeqlabels
```

```stata
drop _all
matrix C = ( 1, .5, 0 \ .5, 1, .3 \ 0, .3, 1 )
drawnorm x1 x2 x3, n(10000) corr(C)
generate y = 1 + x1 + x2 + x3 + 5 * invnorm(uniform())
regress y x1 x2 x3
estimates store m1
generate x1err = x1 + 2 * invnorm(uniform())
regress y x1err x2 x3
estimates store m2
coefplot (m1, label(Without error)) ///
    (m2, label(With error)) ///
    , xline(1) rename(x1err = x1)
```

## 11. 排序

```stata
sysuse auto, clear
label variable mpg "1. mpg"
label variable trunk "{bf:2. trunk}"
label variable length "{bf:3. length}"
label variable turn "4. turn"
regress price mpg length
estimates store m1
regress price mpg trunk turn
estimates store m2
regress price mpg trunk length turn
estimates store m3
coefplot m1 || m2 || m3, xline(0) drop(_cons) byopts(row(1))
coefplot m1 || m2 || m3, xline(0) drop(_cons) byopts(row(1)) orderby(3:)
coefplot m1 || m2 || m3, xline(0) drop(_cons) byopts(row(1)) order(mpg trunk length)
label variable mpg
label variable trunk
label variable length
label variable turn
coefplot m1 || m2 || m3, xline(0) drop(_cons) byopts(row(1)) ///
    order(. mpg . t* . length .)
```

- `orderby(3:)` 按第 3 个子图（或模型）的系数顺序；`order()` 显式排序，`.` 插入空隙，支持通配符。
- 多方程模型可用 `order(5: 4:)` 调整方程顺序，或用 `order(4:1.foreign 5:1.foreign ...)` 跨方程选系数排序。
- `sort` 按估计值排序；`sort(, descending)` 降序；`sort(, by(se))` 按标准误排序；`sort(1, descending)` 指定系列排序；`sort(2:1, descending)` 指定第 2 子图第 1 系列排序。

```stata
sysuse nlsw88, clear
drop if inlist(industry,2)
regress wage ibn.industry, nocons noheader
coefplot, sort
coefplot, sort(, descending)
coefplot, sort(, by(se))
```

```stata
sysuse auto, clear
gen mpp = mpg/8
mlogit rep78 mpp if rep>=3
estimates store m1
mlogit rep78 mpp i.foreign if rep>=3
estimates store m2
coefplot m1 || m2, xline(0) nolabel keep(*:) order(_cons 1.foreign mpp)
coefplot m1 || m2, xline(0) nolabel keep(*:) order(5: 4:)
coefplot m1 || m2, xline(0) nolabel keep(*:) ///
    order(4:1.foreign 5:1.foreign 4:_cons mpp)
```

```stata
sysuse nlsw88, clear
drop if inlist(industry,2)
regress wage ibn.industry, nocons noheader
estimates store overall
regress wage ibn.industry if union==0, nocons
estimates store nonunion
regress wage ibn.industry if union==1, nocons
estimates store union
coefplot overall, nokey ///
    || nonunion union, bylabel(by union status) ///
    || , norecycle byopts(legend(position(5))) sort(1, descending)
coefplot overall, nokey ///
    || nonunion union, bylabel(by union status) ///
    || , norecycle byopts(legend(position(5))) sort(3, descending)
```

```stata
sysuse nlsw88, clear
drop if inlist(industry,1,2,3,10)
regress wage ibn.industry if union==0 & south==0, nocons
estimates store nonunionnorth
regress wage ibn.industry if union==1 & south==0, nocons
estimates store unionnorth
regress wage ibn.industry if union==0 & south==1, nocons
estimates store nonunionsouth
regress wage ibn.industry if union==1 & south==1, nocons
estimates store unionsouth
coefplot nonunionnorth unionnorth, bylabel(North) ///
    || nonunionsouth unionsouth, bylabel(South) ///
    || , plotlabels("nonunion" "union") sort(2:1, descending)
```

## 12. 矩阵绘图

```stata
sysuse auto, clear
matrix median = J(1,3,.)
matrix colnames median = mpg trunk turn
matrix CI = J(2,3,.)
matrix colnames CI = mpg trunk turn
matrix rownames CI = ll95 ul95
local i 0
foreach v of varlist mpg trunk turn {
    local ++i
    quietly centile `v'
    matrix median[1,`i'] = r(c_1)
    matrix CI[1,`i'] = r(lb_1)
    matrix CI[2,`i'] = r(ub_1)
}
coefplot matrix(median), ci(CI)
```

- `matrix(名称)` 从矩阵第一行取点估计；用 `v()` / `se()` / `ci()` 提供 CI。
- 矩阵结果可与估计结果混合，如 `coefplot (., label(mean)) (matrix(R[,1]), ci((2 3)) label(median))`。

```stata
sysuse auto, clear
matrix R = J(5, 3, .)
matrix coln R = median ll95 ul95
matrix rown R = 1 2 3 4 5
forv i = 1/5 {
    quietly centile price if rep78==`i'
    matrix R[`i',1] = r(c_1), r(lb_1), r(ub_1)
}
mean price, over(rep78)
coefplot (., label(mean) rename(^.*([0-9])\..+$ = \1, regex)) ///
    (matrix(R[,1]), ci((2 3)) label(median)) ///
    , ytitle(Repair Record 1978) xtitle(Price)
```

## 13. 改变图型 recast

```stata
sysuse auto, clear
regress price mpg trunk length if foreign==0
estimates store D
regress price mpg trunk length if foreign==1
estimates store F
coefplot (D, label(Domestic Cars)) (F, label(Foreign Cars)) ///
    , drop(_cons) xline(0) recast(bar) ciopts(recast(rcap)) citop barwidth(0.3)
```

- `recast(bar/connected/line/area)` 改变点估计图型；`ciopts(recast(rcap/rline/rbar/pcarrow))` 改变 CI 图型。
- `citop` 把 CI 画在条形前面；`noci` 不画 CI；`cionly` 只画 CI。
- 不同系列可用不同 `recast()`，再用 `nooffsets` 居中对齐、`axis(2)` 分轴。

```stata
sysuse auto, clear
proportion rep78
estimates store prop
mean price, over(rep78)
estimates store mean
coefplot (prop, recast(bar) noci barwidth(0.5) color(*.6)) ///
    (mean, recast(connected) ciopts(recast(rcap)) axis(2)) ///
    , vertical nooffsets plotlabels("Proportion" "Price") ///
      xtitle("Repair record") ytitle("Proportion") ytitle("Price", axis(2)) ///
      rename(^.*([0-9])\..+$ = \1, regex)
```

## 14. 连续轴 at

```stata
sysuse auto, clear
logit foreign mpg
margins, at(mpg=(10(2)40)) post
estimates store bivariate
logit foreign mpg turn price
margins, at(mpg=(10(2)40)) post
estimates store multivariate
coefplot bivariate multivariate, ytitle(Pr(foreign=1)) xtitle(Miles per Gallon) ///
    at recast(line) lwidth(*2) ciopts(recast(rline) lpattern(dash))
```

- 系数代表连续维度上的估计（margins 预测概率/边际效应）时用 `at`；自动关闭偏移。
- 必须用 `margins ..., post` 把结果写入 `e()`。

## 15. 选项层级

```stata
coefplot model1 model2 model3, levels(99 95)                  // 全局默认
coefplot model1 model2 (model3, level(90)), levels(99 95)     // 单个覆盖全局
```

- 层级：globalopts ⊃ subgropts ⊃ plotopts ⊃ modelopts；上层作默认，下层覆盖。
- 规则：`coefplot m1, opts1 || m2, opts2 opts3` 中 `opts2 opts3` 是全局选项；只想作用于 `m2` 写 `coefplot m1, opts1 || m2, opts2 ||, opts3`。
- 括号内：`(m1, opts1 \ m2, opts2)` 中 `opts2` 作用于两个模型；只作用于 `m2` 写 `(m1, opts1 \ m2, opts2 \)`；再加两模型共用 `opts3` 写 `(m1, opts1 \ m2, opts2 \, opts3)` 或 `(m1, opts1 \ m2, opts2 \), opts3`。
- 多子图时，plot 选项会跨子图收集；未指定 `norecycle` 时，后子图的 plot 选项通常优先；也可用全局 `p1() p2()` 给指定系列设默认，系列内选项优先于 `p1()/p2()`。

---

# 第二部分 估计值处理（Examples / Estimates）

## 16. Odds ratios（eform）

```stata
sysuse auto, clear
logit foreign mpg trunk length turn
coefplot, drop(_cons) xline(1) eform xtitle(Odds ratio)
```

- `eform` 把 logit 系数变为 OR（stcox 为 HR、mlogit 为 RRR、poisson 为 IRR）；参考线应改为 1。
- 也可 `transform(* = exp(@))` 达到同样效果。

## 17. 缩放 rescale

```stata
sysuse auto, clear
proportion rep78
coefplot, rescale(100) xtitle(Percent) recast(bar) barwidth(0.5) finten(60) ///
    citop citype(logit) ciopts(recast(rcap))
```

- `rescale(100)` 把比例变百分比；`rescale(weight = 100 gpm = .01)` 只缩放指定系数。
- 比例 CI 建议 `citype(logit)` 让置信限不越界。
- 也可按自变量 SD 做半标准化：把 `summarize` 得到的 `r(sd)` 存成局部宏 ``sd_mpg'``，再 ``rescale(mpg = `sd_mpg' ...)``。

```stata
sysuse auto, clear
generate gpm = 1 / mpg
regress price weight gpm turn
coefplot, drop(_cons) xline(0) rescale(weight = 100 gpm = .01) ///
    coeflabels(weight = "Weight (in 100 lbs.)" gpm = "Gallon per 100 miles")
```

```stata
sysuse auto, clear
regress price mpg weight length turn
foreach v of var mpg weight length turn {
    quietly summarize `v'
    local sd_`v' = r(sd)
}
coefplot, drop(_cons) xline(0)           ///
    rescale(mpg    = `sd_mpg'            ///
            weight = `sd_weight'         ///
            length = `sd_length'         ///
            turn   = `sd_turn')
```

## 18. 变换 transform

```stata
sysuse auto, clear
logit foreign mpg trunk length turn
coefplot (., eform label(eform)) ///
    (., transform(* = exp(@)) label(transform)) ///
    , drop(_cons) xline(1) xtitle(Odds ratio)
```

- `transform(* = 表达式)` 中 `@` 是原值；`eform` → `rescale()` → `transform()` 依次生效。
- 混合模型随机效应：方差取 `exp(@)`、相关取 `tanh(@)` 可画在相近尺度。

```stata
webuse pig, clear
mixed weight week || id: week, covariance(unstructured)
coefplot, noeqlabels keep(ln*: at*:) ///
    transform(ln*: = exp(@) at*: = tanh(@)) ///
    coeflabels(ln*1: = "se(week)" ln*2: = "se(_cons)" ///
        at*: = "corr(week,_cons)" ln*e: = "sd(Residual)")
```

```stata
sysuse auto, clear
regress price ibn.rep78, nocons
coefplot (., cionly transform(* = min(@,@b)) pstyle(p2)) ///
    (., cionly transform(* = max(@,@b)) pstyle(p3)) ///
    (., noci pstyle(p1)) ///
    , nooffsets ciopts(lwidth(*10) lcolor(*.5)) legend(off)
```

## 19. 按值选择系数 if()

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==1
coefplot (., if(@ll<0 & @ul>0)) ///
    (., if(@ll>0 | @ul<0)) ///
    , drop(_cons) nooffsets xline(0) legend(off)
```

- `@ll`/`@ul` 是 CI 上下限临时变量；`if()` 基于数值选系数，常用于显著/不显著分色。

## 20. 标准化系数

```stata
sysuse auto, clear
sem (price <- mpg weight length turn)
coefplot, drop(_cons) xline(0) b(b_std) v(V_std) xtitle(Standardized Coefficients)
```

- coefplot 不直接标准化；可用 `sem` 的 `e(b_std)` / `e(V_std)`，或先 `center ..., standardize` 再回归，或用 `rescale()` 手工缩放。

```stata
* 需先运行：ssc install center, replace
sysuse auto, clear
preserve
center price mpg weight length turn foreign, inplace standardize
regress price mpg weight length turn, noconstant
restore
coefplot, xline(0) xtitle(Standardized Coefficients)
```

## 21. margins 结果

```stata
sysuse auto, clear
logit foreign mpg trunk length turn
margins, dydx(*) post
coefplot, xline(0) xtitle(Average marginal effects)
```

- `margins ..., post` 必须加；否则 `e()` 还是原模型系数。

## 22. mlogit 的 margins

```stata
webuse sysdsn1, clear
mlogit insure i.male i.nonwhite i.site
margins, dydx(*) post
coefplot (, keep(*:1._predict) label(Indemnity)) ///
    (, keep(*:2._predict) label(Prepaid)) ///
    (, keep(*:3._predict) label(Uninsure)) ///
    , swapnames xline(0) legend(rows(1))
```

- mlogit 的 `margins` 结果按 `_predict` 编号分方程；`keep(*:1._predict)` 选对应方程；`swapnames` 把方程名与系数名互换。
- Stata 13 或更早需按方程循环：``quietly margins, dydx(*) post predict(outcome(`o'))``，存成三个模型再 `coefplot Indemnity Prepaid Uninsure`。

```stata
webuse sysdsn1, clear
mlogit insure i.male i.nonwhite i.site
estimates store mlogit
forvalues o = 1/3 {
    local oname: word `o' of Indemnity Prepaid Uninsure
    quietly margins, dydx(*) post predict(outcome(`o'))
    estimates store `oname'
    quietly estimates restore mlogit
}
coefplot Indemnity Prepaid Uninsure, xline(0) legend(rows(1))
```

---

# 第三部分 置信区间（Examples / Confidence intervals）

## 23. 改变 CI 图型

```stata
coefplot domestic foreign, drop(_cons) xline(0) ciopts(recast(rcap))
```

- 默认 spikes；`ciopts(recast(rcap))` 加端帽，`rline` 线，`rbar` 条。

## 24. 多置信水平 levels

```stata
sysuse auto, clear
regress price mpg trunk length turn
coefplot, drop(_cons) xline(0) msymbol(s) mfcolor(white) ///
    levels(99.9 99 95) legend(order(1 "99.9" 2 "99" 3 "95") rows(1))
coefplot, drop(_cons) xline(0) msymbol(s) mfcolor(white) ///
    levels(99.9 99 95) legend(order(1 "99.9" 2 "99" 3 "95") rows(1)) ///
    ciopts(lwidth(*1 *3 *6))
```

- `levels(99 95)` 画多层 CI；`ciopts(lwidth(*1 *3 *6))` 各层线宽；`ciopts(lcolor(...))` 各层颜色。
- 经典样式：`levels(95 50) ciopts(recast(. rcap))`（Cleveland 样式）。

```stata
coefplot, drop(_cons) xline(0) msymbol(d) mcolor(white) ///
    levels(99 95 90 80 70) ciopts(lwidth(3 ..) lcolor(*.2 *.4 *.6 *.8 *1)) ///
    legend(order(1 "99" 2 "95" 3 "90" 4 "80" 5 "70") rows(1))
```

```stata
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store domestic
regress price mpg trunk length turn if foreign==1
estimates store foreign
coefplot domestic foreign, drop(_cons) xline(0) levels(95 50) ciopts(recast(. rcap))
```

## 25. CI 的读取原理

- 方差来自 `e(V)`（mi 估计为 `e(V_mi)`）；有 `e(df_r)` 用 t 分布，否则正态；`df()` 自定义自由度。
- `v(V_srs)` 读取其他方差矩阵；`se()` 提供标准误；`ci()` 使用现成 CI。

```stata
webuse nhanes2f, clear
svyset psuid [pweight=finalwgt], strata(stratid)
svy: regress zinc age age2 weight female black orace rural
coefplot (., label(design-based)) (., v(V_srs) label(SRS-based)) ///
    , keep(female black orace rural) xlabel(,grid)
```

```stata
webuse nhanes2f, clear
svyset psuid [pweight=finalwgt], strata(stratid)
svy: regress zinc age age2 weight female black orace rural
local df_r = e(N) - e(df_m) - 1
coefplot (., label(design-based)) (., v(V_srs) df(`df_r') label(SRS-based)) ///
    , keep(female black orace rural) xlabel(,grid)
```

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

## 关键陷阱速查

1. `margins` 必须加 `post`，否则 coefplot 画的还是原模型系数。
2. `eform` 后参考线是 1，不是 0；`xline(0)` 在 OR 图上无意义。
3. `vertical` 后所有 `x`/`y` 选项对调（`yline(0)`、`ytitle`、`ylabel`）。
4. `bycoefs` 后 `headings()`/`groups()` 用整数编号，不是系数名。
5. `byopts(xrescale)` 允许各子图不同刻度；不加时子图共用刻度，系数尺度差异大时会被压缩。
6. 多模型同名系数会重叠：用 `rename()`、或 `asequation` + `swapnames` 区分。
7. `addplot` 必须加 `norescaling`，否则会破坏 coefplot 的坐标轴。
8. 比例/百分比 CI 用 `citype(logit)`，避免置信限越界；画 bar 时用 `citop` 把 CI 放前面。
9. `mlabels()` 位置参数（1/11/12 等）参考 `help marker_options`；`*` 匹配所有系数。
10. `coefplot` 默认画第一个方程；多方程模型要 `keep(*:)` 或按方程号选择。

## 引用

> Ben Jann. 2025. coefplot: Stata module for plotting regression coefficients and other estimates. Statistical Software Components, Boston College Department of Economics. https://repec.sowi.unibe.ch/stata/coefplot/
