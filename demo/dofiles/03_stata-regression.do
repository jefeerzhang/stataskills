*==========================================================*
* DEMO 3/5 : stata-regression —— 方差分析与回归建模（书第 9–11 章）
* 技能源   : stata-regression/SKILL.md
* 数据     : auto.dta
*==========================================================*
version 19.5
set more off
clear all
sysuse auto, clear

*---- 第 9 章：ANOVA / ANCOVA -----------------------------
oneway price foreign, tabulate
oneway mpg foreign
anova price c.weight foreign
anova mpg foreign rep78

*---- 第 10 章：多元回归 ----------------------------------
regress price mpg weight length displacement, beta
regress price mpg weight length displacement
estat vif

* 残差诊断
predict r, residual
sktest r
rvfplot, yline(0) title("Residuals vs Fitted") scheme(s1mono)
graph export "output/03_rvfplot.png", replace

* 稳健标准误
regress price mpg weight length displacement, vce(robust)

* 因子变量 + 交互
regress price mpg weight i.foreign, beta
test 1.foreign
regress price c.weight##i.foreign
margins foreign, at(weight=(2000(500)4500))
marginsplot, noci title("Price: weight x origin") scheme(s1mono)
graph export "output/03_margins_interaction.png", replace

* 非线性（二次项）
regress price c.weight##c.weight
margins, at(weight=(2000(500)4500))
marginsplot, noci title("Price vs Weight (quadratic)") scheme(s1mono)
graph export "output/03_margins_quadratic.png", replace

* 回归功效
power rsquared 0.30, power(0.90) ntested(4)

*---- 第 11 章：逻辑回归 ----------------------------------
logistic foreign mpg weight price
logit foreign mpg weight price
margins, dydx(mpg) atmeans
margins, at(mpg=(15(5)40)) atmeans
marginsplot, title("Predicted P(foreign) by MPG") scheme(s1mono)
graph export "output/03_logit_margins.png", replace

*---- 第 10.5 章：高维固定效应 reghdfe -----------------------
* 检测 reghdfe 是否安装（与 verify 同款设计：未装则跳过）
cap which reghdfe
if _rc == 0 {
    * 多维 FE：auto.dta 的 foreign × rep78 两层
    * rep78 有 5 缺失，reghdfe 会自动剔除单点组
    reghdfe price mpg weight length, absorb(foreign rep78)

    * 多向聚类稳健 SE（cluster 到 foreign + rep78 两向）
    reghdfe price mpg weight length, absorb(foreign rep78) vce(cluster foreign rep78)

    * 残差对比：reghdfe vs regress i.foreign 在相同设定下应几乎完全相同
    * 注意：reghdfe 不能事后 predict, resid——必须在估计时加 residuals 选项保存
    reghdfe price mpg weight length, absorb(foreign) residuals(hdfe_resid)
    regress price mpg weight length i.foreign
    predict ols_resid, resid
    twoway (scatter hdfe_resid ols_resid) (function y = x, range(-5 5)), ///
        title("reghdfe resid vs regress i.fe resid (should lie on y=x)") ///
        legend(off) scheme(s1mono) ///
        xtitle("reghdfe residual") ytitle("regress residual")
    graph export "output/03_reghdfe_resid_compare.png", replace
}

*---- 第 10.6 章：IV + 多维固定效应 ivreghdfe -----------------------
* 检测 ivreghdfe 三件套是否都装；未装则跳过但 do-file 仍 PASS（与 verify 同款）
cap which ivreghdfe
if _rc == 0 {
    * IV + 单层 FE：mpg 当内生变量，displacement 当工具变量（语法演示；
    * 经济学上 mpg 与 displacement 高度相关，可作工具）
    ivreghdfe price weight length (mpg = displacement), absorb(foreign)

    * IV + 两向聚类稳健 SE
    ivreghdfe price weight length (mpg = displacement), absorb(foreign) cluster(foreign)
}
