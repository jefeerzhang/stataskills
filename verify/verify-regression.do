version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-regression
* chapter:  ch9
* data:     partyid.dta;gss2006_chapter9.dta;gss2006_chapter9_2way.dta;ops2004.dta;c10interaction.dta;nlsy97_chapter11.dta;environ.dta;sim:100x10
* checks:   anova+regress+ivregress+ivreg2+ivreghdfe+weakivtest+iv-identification
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
cap which ranktest
local has_ranktest = (_rc == 0)
if !`has_ranktest' {
    display "__COMMUNITY_PACKAGE_MISSING__ranktest__"
}
local can_ivreghdfe = (`has_ivreghdfe' & `can_reghdfe' & `has_ivreg2' & `has_ranktest')
if `can_ivreghdfe' {
    use gss2006_chapter9_2way, clear
    * IV + 单层 FE：prestg80 当内生变量（prestige 可能有反向因果），
    * age 当工具变量，marital 当 FE。变量互不重叠。
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital)

    * IV + 异方差稳健 SE（ivreghdfe 用 ivreg2 语法：`robust` 直接选项；
    * 注意：选项之间是空格分隔（不是逗号），否则 ivreghdfe 解析器拒为 invalid syntax）
    ivreghdfe tvhours sex (prestg80 = age), absorb(marital) robust
}

* ---- ch10.6a 官方 ivregress（内置，无需外部包）----
* 验证官方 IV 栈（ivregress + estat firststage/endogenous/overid）能跑通
* 两段：
*   1. 恰好识别（1 内生 + 1 工具）— `estat overid` 会用 `capture` 兜住 r(498)，
*      这不是失败，是 Stata 表达"无过度识别可做"的合法退出码
*      （详见 SKILL.md「错误码速查」r(498)）。
*   2. 过度识别（1 内生 + 2 工具）— `estat overid` 正常输出 Score chi2 与 p。
use gss2006_chapter9_2way, clear
ivregress 2sls tvhours sex (prestg80 = age), vce(robust) first
estat firststage
estat endogenous
capture noisily estat overid
display "overid_exact_rc=" _rc

ivregress 2sls tvhours sex (prestg80 = age marital), vce(robust)
estat overid

* ---- ch10.8-10.9 外部 IV 栈：非线性内生项 + weakivtest ----
* weakivtest help：只支持一个内生变量，并要求 avar；先用双内生模型验证
* x1_sq/z1_sq 括号语法，再用单内生模型验证 effective F。
cap which weakivtest
local has_weakivtest = (_rc == 0)
if !`has_weakivtest' {
    display "__COMMUNITY_PACKAGE_MISSING__weakivtest__"
}
cap which avar
local has_avar = (_rc == 0)
if !`has_avar' {
    display "__COMMUNITY_PACKAGE_MISSING__avar__"
}
local can_ivreg2_sim = (`has_ivreg2' & `has_ranktest')
if `can_ivreg2_sim' {
    clear
    set seed 20260825
    set obs 1000
    generate long id = ceil(_n / 10)
    bysort id: generate int year = 2000 + _n - 1
    generate double z1 = rnormal()
    generate double z1_sq = z1^2
    generate double x2 = rnormal()
    generate double x3 = rnormal()
    generate double u = rnormal()
    generate double x1 = 0.8*z1 + 0.3*x2 + 0.4*u + rnormal()
    generate double x1_sq = x1^2
    generate double y = 1.2*x1 - 0.2*x1_sq + 0.4*x2 - 0.1*x3 + u + rnormal()
    xtset id year

    ivreg2 y x2 x3 i.year (x1 x1_sq = z1 z1_sq), ///
        cluster(id) first ffirst endog(x1)

    local can_weakivtest = (`has_weakivtest' & `has_avar')
    if `can_weakivtest' {
        ivreg2 y x2 x3 i.year (x1 = z1), cluster(id)
        weakivtest
        display "weakivtest_F_eff=" r(F_eff)
    }
}

* ---- ch10.10 官方 IV 结果三角（内置命令即可，不依赖社区包）----
* 三类回归必须共享样本、外生控制与 vce；恰好识别时
*   beta_2SLS = reduced-form z1 系数 / first-stage z1 系数
* 这是结果链检查，不检验排除限制。
clear
set seed 20260825
set obs 1000
generate double z1 = rnormal()
generate double x2 = rnormal()
generate double x3 = rnormal()
generate double u = rnormal()
generate double x1 = 0.8*z1 + 0.3*x2 + 0.4*u + rnormal()
generate double y = 1.2*x1 + 0.4*x2 - 0.1*x3 + u + rnormal()

regress x1 z1 x2 x3, vce(robust)
local triangle_n = e(N)
scalar triangle_first_z1 = _b[z1]

regress y z1 x2 x3, vce(robust)
assert e(N) == `triangle_n'
scalar triangle_reduced_z1 = _b[z1]

ivregress 2sls y x2 x3 (x1 = z1), vce(robust) first
estat firststage
assert e(N) == `triangle_n'
scalar triangle_iv_x1 = _b[x1]
assert abs(triangle_reduced_z1 / triangle_first_z1 - triangle_iv_x1) < 1e-8
display "iv_triangle_wald=" triangle_reduced_z1 / triangle_first_z1
