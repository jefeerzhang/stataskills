version 19.5

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
* 检测 reghdfe 是否安装；未装则跳过但 do-file 仍 PASS（cap 包住不报错）
cap which reghdfe
if _rc == 0 {
    use gss2006_chapter9_2way, clear
    * 多维 FE：workfull × married
    reghdfe tvhours age, absorb(workfull married)
    * 多向聚类稳健 SE
    reghdfe tvhours age, absorb(workfull married) vce(cluster workfull married)
    * 报告 Within R² + 吸收 DoF 表（reghdfe 默认行为）
    reghdfe tvhours age, absorb(workfull married) residuals
}

* ---- ch10.6 IV + 多维固定效应 ivreghdfe ----
* 检测 ivreghdfe + ivreg2 三件套是否都装；未装则跳过但 do-file 仍 PASS
* ivreghdfe 要求工具变量/FE/cluster 变量互不重叠
cap which ivreghdfe
if _rc == 0 {
    use gss2006_chapter9_2way, clear
    * IV + 单层 FE：prestg80 当内生变量（prestige 可能有反向因果），
    * age 当工具变量，marital 当 FE。变量互不重叠。
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital)

    * IV + 异方差稳健 SE（ivreghdfe 用 ivreg2 语法：`robust` 直接选项；
    * 注意：选项之间是空格分隔（不是逗号），否则 ivreghdfe 解析器拒为 invalid syntax）
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital) robust
}
