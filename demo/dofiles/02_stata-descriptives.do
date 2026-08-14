*==========================================================*
* DEMO 2/5 : stata-descriptives —— 描述统计/图形/检验（书第 5–8 章）
* 技能源   : skills/stata-descriptives/SKILL.md
* 数据     : auto.dta
*==========================================================*
version 19.5
set more off
clear all
sysuse auto, clear

*---- 第 5 章：单变量描述统计 -----------------------------
tab1 foreign rep78
summarize price mpg weight length, detail
tabstat price mpg weight length, statistics(mean median sd iqr skewness kurtosis) ///
        by(foreign) columns(statistics)

* 正态性检验
sktest mpg
sktest price

* 图形：直方图、箱线图
histogram price, freq title("Distribution of Price") scheme(s1mono)
graph export "output/02_hist_price.png", replace
histogram mpg, freq title("Distribution of MPG") scheme(s1mono)
graph export "output/02_hist_mpg.png", replace
graph hbox mpg, over(foreign) title("MPG by Car Origin") scheme(s1mono)
graph export "output/02_hbox_mpg_by_foreign.png", replace

*---- 第 6 章：两分类变量交叉表与卡方 ----------------------
tabulate rep78 foreign, chi2 row V
tabulate rep78 foreign, chi2 expected

*---- 第 7 章：均值检验与功效 -----------------------------
ttest price, by(foreign)
ttest mpg, by(foreign)
esize twosample mpg, by(foreign) cohensd hedgesg
power twomeans 20 25, sd(6) power(0.90)

*---- 第 8 章：相关与双变量回归 ---------------------------
pwcorr price mpg weight length displacement, obs sig star(5)
correlate price mpg weight length displacement

twoway (scatter price mpg) (lfit price mpg), ///
       title("Price vs MPG") legend(off) scheme(s1mono)
graph export "output/02_scatter_price_mpg.png", replace

regress price mpg
regress price weight, beta
