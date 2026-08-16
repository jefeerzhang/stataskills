*==========================================================*
* DEMO 2/5 : stata-descriptives —— 描述统计/图形/检验（书第 5–8 章）
* 技能源   : stata-descriptives/SKILL.md
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

*---- 第 8.5 章：面板数据可视化 panelview -----------------------
* 检测 panelview 是否安装；未装则跳过但 do-file 仍 PASS（与 verify 同款）
cap which panelview
if _rc == 0 {
    * 用 longitudinal_mixed.dta（5,474 obs × 1,554 人 × 6 波，1998-2008）
    use "../data/agis6/longitudinal_mixed.dta", clear
    keep id drink98 drink00 drink02 drink04 drink06 drink08
    reshape long drink, i(id) j(wave)
    replace drink = . if drink < 0   // -9 表示缺失

    * 缺失模式
    panelview drink, type(missing) i(id) t(wave)
    graph export "output/02_panelview_missing.png", replace

    * 处理状态（drink>=2 当 treat）
    gen treat = (drink >= 2) if drink != .
    panelview treat, type(treat) i(id) t(wave)
    graph export "output/02_panelview_treat.png", replace
}
