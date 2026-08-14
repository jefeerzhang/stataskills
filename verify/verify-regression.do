* ============================================================
* 验证脚本：stata-regression（第 9–11 章核心命令）
* 数据来源：data/agis6/
* ============================================================
version 15
set more off

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

display "VERIFY REGRESSION DONE"
exit, clear
