version 19.5

* ============================================================
* stata-coefplot 验证脚本
* 覆盖 SKILL.md 核心可执行路径：基本图 / 多模型 / 子图 /
* bycoefs / 排序 / 矩阵 / recast / at / eform / 标签 / markers
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
