*==========================================================*
* DEMO 6/6 : stata-coefplot —— 系数图（森林图）示例
* 技能源   : stata-coefplot/SKILL.md
* 数据     : auto.dta / nlsw88（Stata 自带）
* 运行     : stata-mp -b do dofiles/06_stata-coefplot.do
*==========================================================*
version 19.5
set more off
clear all

*---- 图 1：多模型系数对比（基础森林图） --------------------
sysuse auto, clear
regress price mpg trunk length turn if foreign==0
estimates store Domestic
regress price mpg trunk length turn if foreign==1
estimates store Foreign
coefplot (Domestic, label(Domestic Cars) pstyle(p3)) ///
        (Foreign, label(Foreign Cars) pstyle(p4)) ///
        , drop(_cons) xline(0) msymbol(S) ///
        title("Regression coefficients by car origin") ///
        scheme(s1mono)
graph export "output/06_coefplot_basic.png", replace

*---- 图 2：条形图 + 置信区间（recast bar） -----------------
sysuse auto, clear
regress price mpg trunk length if foreign==0
estimates store Domestic
regress price mpg trunk length if foreign==1
estimates store Foreign
coefplot (Domestic, label(Domestic Cars)) (Foreign, label(Foreign Cars)) ///
        , drop(_cons) xline(0) recast(bar) ciopts(recast(rcap)) citop barwidth(0.3) ///
        title("Coefficient bars with capped CIs") ///
        scheme(s1mono)
graph export "output/06_coefplot_bar.png", replace

*---- 图 3：连续轴上的边际预测（margins + at） ---------------
sysuse auto, clear
logit foreign mpg
margins, at(mpg=(10(2)40)) post
estimates store bivariate
logit foreign mpg turn price
margins, at(mpg=(10(2)40)) post
estimates store multivariate
coefplot bivariate multivariate, ytitle(Pr(foreign=1)) xtitle(Miles per Gallon) ///
        at recast(line) lwidth(*2) ciopts(recast(rline) lpattern(dash)) ///
        title("Predicted probability of foreign car by MPG") ///
        scheme(s1mono)
graph export "output/06_coefplot_at.png", replace

*---- 图 4：按系数分面（bycoefs） ---------------------------
sysuse auto, clear
forvalues i = 3/5 {
    quietly regress price mpg headroom weight turn if rep78==`i'
    estimates store rep78_`i'
}
coefplot rep78_3 || rep78_4 || rep78_5, drop(_cons) xline(0) ///
        bycoefs byopts(xrescale) ///
        title("Coefficients by repair record (bycoefs)") ///
        scheme(s1mono)
graph export "output/06_coefplot_bycoefs.png", replace
