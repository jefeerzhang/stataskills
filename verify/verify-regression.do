version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-regression
* chapter:  ch9
* data:     partyid.dta
* checks:   anova+regress
* ============================
* ---- ch9 ANOVA ----
use partyid, clear
oneway stemcell partyid, bonferroni tabulate
kwallis stemcell, by(partyid)
use gss2006_chapter9, clear
anova prestg80 mobile16 c.age if age > 29 & age < 60 & wrkstat==1
margins mobile16, atmeans
use gss2006_chapter9_2way, clear
anova tvhours workfull married workfull#married

* ---- ch10 多元回归 ----
use ops2004, clear
regress env_con educat inc com3 hlthprob epht3, beta
pcorr env_con educat inc com3 hlthprob epht3
estat vif
regress env_con educat inc com3 hlthprob epht3, vce(robust)
use c10interaction, clear
regress inc i.male##c.educ, beta

* ---- ch11 逻辑回归 ----
use nlsy97_chapter11, clear
logistic drank30 age97 male pdrink97 dinner97
logit drank30 age97 male pdrink97 dinner97
generate black = race97 - 1
replace black = . if race97 > 2
logit drank30 age97 i.black pdrink97 dinner97
margins, dydx(black) atmeans
margins, at(pdrink97=(1 2 3 4 5)) atmeans
use environ, clear
tab2 environ libcand, row

* ---- ch10.5 高维固定效应 reghdfe ----
* 检测 reghdfe 及当前依赖；缺任一项则发 sentinel 并跳过该段
cap which reghdfe
local has_reghdfe = (_rc == 0)
if !`has_reghdfe' {
    display "__COMMUNITY_PACKAGE_MISSING__reghdfe__"
}
cap which require
local has_require = (_rc == 0)
if !`has_require' {
    display "__COMMUNITY_PACKAGE_MISSING__require__"
}
cap which ftools
local has_ftools = (_rc == 0)
if !`has_ftools' {
    display "__COMMUNITY_PACKAGE_MISSING__ftools__"
}
local can_reghdfe = (`has_reghdfe' & `has_require' & `has_ftools')
if `can_reghdfe' {
    use gss2006_chapter9_2way, clear
    * 多维 FE：workfull × married
    reghdfe tvhours age, absorb(workfull married)
    * 多向聚类稳健 SE
    reghdfe tvhours age, absorb(workfull married) vce(cluster workfull married)
    * 报告 Within R² + 吸收 DoF 表（reghdfe 默认行为）
    reghdfe tvhours age, absorb(workfull married) residuals
}

* ---- ch10.6 IV + 多维固定效应 ivreghdfe ----
* 检测 ivreghdfe + ivreg2 依赖；未装则发 sentinel 并跳过该段
* ivreghdfe 要求工具变量/FE/cluster 变量互不重叠
cap which ivreghdfe
local has_ivreghdfe = (_rc == 0)
if !`has_ivreghdfe' {
    display "__COMMUNITY_PACKAGE_MISSING__ivreghdfe__"
}
cap which ivreg2
local has_ivreg2 = (_rc == 0)
if !`has_ivreg2' {
    display "__COMMUNITY_PACKAGE_MISSING__ivreg2__"
}
local can_ivreghdfe = (`has_ivreghdfe' & `can_reghdfe' & `has_ivreg2')
if `can_ivreghdfe' {
    use gss2006_chapter9_2way, clear
    * IV + 单层 FE：prestg80 当内生变量（prestige 可能有反向因果），
    * age 当工具变量，marital 当 FE。变量互不重叠。
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital)

    * IV + 异方差稳健 SE（ivreghdfe 用 ivreg2 语法：`robust` 直接选项；
    * 注意：选项之间是空格分隔（不是逗号），否则 ivreghdfe 解析器拒为 invalid syntax）
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital) robust
}
