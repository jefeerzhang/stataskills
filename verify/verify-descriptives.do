* ============================================================
* 验证脚本：stata-descriptives（第 5–8 章核心命令）
* 数据来源：data/agis6/
* ============================================================
version 15
set more off

* ---- ch5 描述统计 ----
use descriptive_gss, clear
tab1 sex marital
summarize polviews, detail
tabstat wwwhr, statistics(mean median sd iqr skewness kurtosis) by(sex) columns(statistics)

* ---- ch6 交叉表与卡方 ----
use gss2006_chapter6, clear
tabulate sex abany, chi2 expected row V
tabulate sex abany, chi2 row V
use chapter6_aspirin, clear
tabulate aspirin heartattack, chi2 row V

* ---- ch7 均值与比例检验 ----
use gss2002_chapter7, clear
recode prayer (1=1) (2=0), gen(schpray)
prtest schpray == 0.5
ttest hrs1 == 40 if wrkstat == 1
ttest paeduc == maeduc
use wide, clear
prtest treat == control

* ---- ch8 相关与回归 ----
use gss2006_chapter8_selected, clear
pwcorr prestg80 hrs1, obs sig
regress prestg80 hrs1, beta
use spearman, clear
spearman age liberal

display "VERIFY DESCRIPTIVES DONE"
exit, clear
