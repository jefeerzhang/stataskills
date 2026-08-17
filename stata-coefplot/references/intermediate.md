---
name: stata-coefplot-intermediate
description: coefplot 常用功能参考（Ben Jann 手册第 8–25 章对应内容）。覆盖按系数分面 bycoefs、通配符模型名、系数匹配、排序、矩阵绘图、改变图型 recast、连续轴 at、选项层级、Odds ratios (eform)、缩放 rescale、变换 transform、按值选择系数、标准化系数、margins 结果、mlogit 的 margins、改变 CI 图型、多置信水平 levels、CI 读取原理。主文件见 `stata-coefplot/SKILL.md`。
---

# stata-coefplot 常用功能（第 8–25 章）

> **加载时机**：主 `SKILL.md`（1–7 章入门）已读完，遇到"多模型 + 多子图 + 排序 + OR + recast + margins"中任一需求时加载本文件。本文件对应 Ben Jann coefplot 手册里最常用的中段功能。
>
> **本文件不重复主文件内容**——只补 8–25 章的具体语法与陷阱修复。所有"陷阱"统一收录在主 `SKILL.md` 的「关键陷阱速查」节。

---

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

