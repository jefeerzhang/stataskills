*==========================================================*
* DEMO 3/5 : stata-regression —— 方差分析与回归建模（书第 9–11 章）
* 技能源   : skills/stata-regression/SKILL.md
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
