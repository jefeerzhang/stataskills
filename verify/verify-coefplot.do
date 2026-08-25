version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-coefplot
* chapter:  coefplot
* data:     sysuse:auto+nlsw88
* checks:   basic+multimodel+subplot+eform
* ============================

* ============================================================
* stata-coefplot 验证脚本
* 覆盖 SKILL.md 核心可执行路径：基本图 / 多模型 / 子图 /
* bycoefs / 排序 / 矩阵 / recast / at / eform / 标签 / markers /
* 官网 getting-started / estimates / confidence-intervals 补充示例
* 所有图形命令在批处理模式下静默执行，不导出文件。
* ============================================================
set more off

* ---- 1. 基本用法 ----
sysuse auto, clear
regress price mpg trunk length turn
coefplot, drop(_cons) xline(0)

* ---- 2. keep/drop 与多方程 ----
sysuse auto, clear
gen mpp = mpg/8
mlogit rep78 mpp i.foreign if rep78>=3
coefplot, nolabel drop(_cons) keep(*:) omitted baselevels
coefplot, nolabel keep(3:*.foreign 4:mpp 5:mpp _cons) omitted baselevels

* ---- 3. 多模型多系列 + 偏移 ----
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store D
regress price mpg trunk length turn if foreign==1
estimates store F
coefplot (D, label(Domestic Cars) offset(0.05)) ///
    (F, label(Foreign Cars) offset(-0.05)) ///
    , drop(_cons) xline(0) msymbol(S)

* ---- 4. 子图与 bycoefs ----
forvalues i = 3/5 {
    quietly regress price mpg headroom weight turn if rep78==`i'
    estimates store rep78_`i'
}
coefplot rep78_3 || rep78_4 || rep78_5, drop(_cons) xline(0) ///
    bycoefs byopts(xrescale)

* ---- 5. 排序 ----
sysuse nlsw88, clear
drop if inlist(industry,2)
regress wage ibn.industry, nocons noheader
coefplot, sort
coefplot, sort(, descending)

* ---- 6. 矩阵绘图 ----
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

* ---- 7. recast 条形图 ----
sysuse auto, clear
regress price mpg trunk length if foreign==0
estimates store D
regress price mpg trunk length if foreign==1
estimates store F
coefplot (D, label(Domestic Cars)) (F, label(Foreign Cars)) ///
    , drop(_cons) xline(0) recast(bar) ciopts(recast(rcap)) citop barwidth(0.3)

* ---- 8. 连续轴 at（margins） ----
sysuse auto, clear
logit foreign mpg
margins, at(mpg=(10(2)40)) post
estimates store bivariate
logit foreign mpg turn price
margins, at(mpg=(10(2)40)) post
estimates store multivariate
coefplot bivariate multivariate, ytitle(Pr(foreign=1)) xtitle(Miles per Gallon) ///
    at recast(line) lwidth(*2) ciopts(recast(rline) lpattern(dash))

* ---- 9. eform ----
sysuse auto, clear
logit foreign mpg trunk length turn
coefplot, drop(_cons) xline(1) eform xtitle(Odds ratio)

* ---- 10. 标签：headings/groups/eqlabels ----
sysuse auto, clear
keep if rep78>=3
regress mpg headroom i.rep##i.foreign
coefplot, xline(0) omitted baselevels drop(_cons) ///
    headings(3.rep78 = "{bf:Repair Record}" ///
        0.foreign = "{bf:Car Type}" ///
        3.rep78#0.foreign = "{bf:Interaction Effects}")
coefplot, xline(0) coeflabels(1.foreign = "Foreign Car" _cons = "Constant")

* ---- 11. markers：noci/cionly/mlabel/weight ----
sysuse auto, clear
regress price mpg trunk length turn
coefplot (., noci label(Markers only)) ///
    (., cionly label(CIs only) key(ci)) ///
    , drop(_cons)
coefplot, xline(0) mlabel format(%9.2g) mlabposition(12) mlabgap(*2)
coefplot, weight(1/@se) ms(oh) drop(_cons) xline(0)

* ---- 12. 模型名作为系数名（asequation + swapnames） ----
sysuse nlsw88, clear
foreach i in 4 6 7 11 12 {
    quietly regress wage grade ttl_exp tenure if industry==`i'
    estimates store industry_`i'
}
coefplot (industry_*), keep(grade) asequation swapnames ///
    title("Effect of grade on wages by industry")


* ---- 13. p1/p2 按位置设置系列选项 ----
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store D
regress price mpg trunk length turn if foreign==1
estimates store F
coefplot D F, drop(_cons) xline(0) msymbol(S) ///
    p1(label(Domestic Cars) pstyle(p3)) ///
    p2(label(Foreign Cars)  pstyle(p4))

* ---- 14. 多模型子图 / _skip / byopts / subtitle ----
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
coefplot D, bylabel(Domestic Cars) || F, bylabel(Foreign Cars) ///
    ||, drop(_cons) xline(0) byopts(compact cols(1))
coefplot D, bylabel(Domestic Cars) || F, bylabel(Foreign Cars) ///
    ||, drop(_cons) xline(0) byopts(compact cols(1)) ///
    subtitle(, size(vlarge) margin(medium) justification(left) ///
        color(white) bcolor(black) bmargin(top_bottom))

* ---- 15. bycoefs + plotlabels ----
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

* ---- 16. 通配符：asequation / 展开为多个系列 ----
sysuse auto, clear
foreach var of varlist mpg trunk length turn {
    quietly regress price `var' if foreign==0
    estimates store d_`var'
    quietly regress price `var' if foreign==1
    estimates store f_`var'
}
coefplot (d*, asequation(Domestic) \ f*, asequation(Foreign) \ , pstyle(p4)) ///
    , drop(_cons) xline(0) title("Bivariate effects on price by car type")

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

sysuse auto, clear
forvalues i=3/5 {
    quietly regress price mpg trunk if rep78==`i'
    estimates store rep_`i'
}
coefplot rep*, drop(_cons) xline(0) ///
    p1(pstyle(p3) label("Rep=3")) ///
    p2(pstyle(p4) label("Rep=4")) ///
    p3(pstyle(p5) label("Rep=5"))

* ---- 17. 系数匹配：eqstrict / asequation / noeqlabels / rename ----
* laborsub 是 StataCorp 官方 webuse 库数据集（已婚妇女工时与工资子样本，
* N=250，字段 lfp whrs kl6 k618 wa we），原示例用 webuse laborsub。
* 为支持离线 / 网络受限环境验证，本仓库在 data/webuse/ 维护本地副本
* （来源 https://www.stata-press.com/data/r16/laborsub.dta，3501 字节，
* 字节校验脚本 data/webuse/download_laborsub.sh）。详见 ADR-0003。
use "../webuse/laborsub.dta", clear
regress whrs kl6 k618 wa we
estimates store regress
tobit whrs kl6 k618 wa we, ll(0)
estimates store tobit
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

* ---- 18. 排序：自动 / order 通配符 / 多方程 / 多系列 ----
sysuse auto, clear
label variable mpg    "1. mpg"
label variable trunk  "{bf:2. trunk}"
label variable length "{bf:3. length}"
label variable turn   "4. turn"
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

* ---- 19. 矩阵 + 估计结果混合 ----
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

* ---- 20. recast：proportion 柱 + mean 连线双轴 ----
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

* ---- 21. rescale：指定系数 / SD 半标准化 ----
sysuse auto, clear
generate gpm = 1 / mpg
regress price weight gpm turn
coefplot, drop(_cons) xline(0) rescale(weight = 100 gpm = .01) ///
    coeflabels(weight = "Weight (in 100 lbs.)" gpm = "Gallon per 100 miles")

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

* ---- 22. transform：用 @b 给 CI 上下半段分色 ----
sysuse auto, clear
regress price ibn.rep78, nocons
coefplot (., cionly transform(* = min(@,@b)) pstyle(p2)) ///
    (., cionly transform(* = max(@,@b)) pstyle(p3)) ///
    (., noci pstyle(p1)) ///
    , nooffsets ciopts(lwidth(*10) lcolor(*.5)) legend(off)

* ---- 23. center 标准化（可选包；未安装则发可选 sentinel） ----
cap which center
if _rc != 0 {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__center__"
}
else {
    sysuse auto, clear
    preserve
    center price mpg weight length turn foreign, inplace standardize
    regress price mpg weight length turn, noconstant
    restore
    coefplot, xline(0) xtitle(Standardized Coefficients)
}

* ---- 24. mlogit margins 老版本循环 ----
* 原示例 webuse sysdsn1 依赖网络；用确定性模拟数据验证相同语法。
clear
set seed 20260823
set obs 600
gen byte insure = mod(_n-1, 3) + 1
gen byte male = mod(_n, 2)
gen byte nonwhite = mod(floor((_n-1)/2), 2)
gen byte site = mod(floor((_n-1)/4), 3) + 1
mlogit insure i.male i.nonwhite i.site
estimates store mlogit
forvalues o = 1/3 {
    local oname: word `o' of Indemnity Prepaid Uninsure
    quietly margins, dydx(*) post predict(outcome(`o'))
    estimates store `oname'
    quietly estimates restore mlogit
}
coefplot Indemnity Prepaid Uninsure, xline(0) legend(rows(1))

* ---- 25. levels：lwidth / Harrell / Cleveland ----
sysuse auto, clear
regress price mpg trunk length turn
coefplot, drop(_cons) xline(0) msymbol(s) mfcolor(white) ///
    levels(99.9 99 95) legend(order(1 "99.9" 2 "99" 3 "95") rows(1)) ///
    ciopts(lwidth(*1 *3 *6))
coefplot, drop(_cons) xline(0) msymbol(d) mcolor(white) ///
    levels(99 95 90 80 70) ciopts(lwidth(3 ..) lcolor(*.2 *.4 *.6 *.8 *1)) ///
    legend(order(1 "99" 2 "95" 3 "90" 4 "80" 5 "70") rows(1))

sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store domestic
regress price mpg trunk length turn if foreign==1
estimates store foreign
coefplot domestic foreign, drop(_cons) xline(0) levels(95 50) ciopts(recast(. rcap))

* ---- 26. svy：V_srs 未修正/修正 df ----
* 原示例 webuse nhanes2f 依赖网络；本地模拟分层整群样本保留 e(V_srs)。
clear
set seed 20260823
set obs 1000
gen int psuid = ceil(_n/10)
gen byte stratid = ceil(psuid/10)
gen double finalwgt = 1 + runiform()
gen double age = 20 + 50*runiform()
gen double age2 = age^2
gen double weight = 45 + 45*runiform()
gen byte female = mod(_n, 2)
gen byte black = mod(floor((_n-1)/2), 2)
gen byte orace = mod(floor((_n-1)/4), 2)
gen byte rural = mod(floor((_n-1)/8), 2)
gen double zinc = 50 + 0.2*age + 0.1*weight - 2*female + rnormal()
svyset psuid [pweight=finalwgt], strata(stratid)
svy: regress zinc age age2 weight female black orace rural
coefplot (., label(design-based)) (., v(V_srs) label(SRS-based)) ///
    , keep(female black orace rural) xlabel(,grid)
local df_r = e(N) - e(df_m) - 1
coefplot (., label(design-based)) (., v(V_srs) df(`df_r') label(SRS-based)) ///
    , keep(female black orace rural) xlabel(,grid)

* ---- 27. 截断 CI：灰色绘图区 / if + pcarrow ----
sysuse nlsw88, clear
regress wage ibn.occupation, nocons
coefplot, transform(* = min(max(@,2),12)) ///
    plotregion(color(gray) icolor(white)) grid(nogextend)
coefplot (., pstyle(p1) if(@ll>2&@ul<12)) ///
    (., pstyle(p1) if(@ll>2&@ul>=12)  ciopts(recast(pcarrow)))  ///
    (., pstyle(p1) if(@ll<=2&@ul<12)  ciopts(recast(pcrarrow))) ///
    (., pstyle(p1) if(@ll<=2&@ul>=12) ciopts(recast(pcbarrow))) ///
    , nooffset transform(* = min(max(@,2),12)) legend(off)
