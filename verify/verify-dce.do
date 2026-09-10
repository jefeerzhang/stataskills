version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-dce
* chapter:  choice-models
* data:     sim:30x4x3
* checks:   cmset+clogit+wtp+mixlogit+lclogitpr+probcalc
* =========================

display "DCE_CONTRACT_REQUIRED"
clear
set seed 20260910
set obs 30
gen respondent = _n
expand 4
bysort respondent: gen task = _n
expand 3
bysort respondent task: gen alternative = _n
gen price = alternative + rnormal()
gen quality = (alternative == 2) + rnormal()
gen latent = -.7 * price + .9 * quality + rnormal()
bysort respondent task: egen maxlatent = max(latent)
gen chosen = latent == maxlatent
drop latent maxlatent

isid respondent task alternative
by respondent task: egen nalt = count(alternative)
by respondent task: egen nchosen = total(chosen)
assert nalt == 3
assert nchosen == 1
display "DCE_CHOICESET_INVARIANT_OK"

cmset respondent task alternative
display "DCE_CMSET_OK"
cmclogit chosen price quality, vce(cluster respondent)
assert e(N) > 0
assert e(converged) == 1
display "DCE_CL_RESULTS_OK"

cmmixlogit chosen price, random(quality) ///
    intmethod(random) intpoints(10) intseed(20260910) ///
    vce(cluster respondent)
assert e(N) > 0
assert e(converged) == 1
display "DCE_MIXED_LOGIT_OK"

cap which mixlogit
local has_mixlogit = (_rc == 0)
if !`has_mixlogit' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__mixlogit__"
}
cap which lclogit
local has_lclogit = (_rc == 0)
if !`has_lclogit' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__lclogit__"
}
cap which fmlogit
local has_fmlogit = (_rc == 0)
if !`has_fmlogit' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__fmlogit__"
}
cap which wtp
local has_wtp = (_rc == 0)
if !`has_wtp' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__wtp__"
}
cap which probcalc
local has_probcalc = (_rc == 0)
if !`has_probcalc' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__probcalc__"
}

egen grid = group(respondent task)
clogit chosen price quality, group(grid) vce(cluster respondent)
assert e(converged) == 1
* 注意：cmclogit 默认拟合带 alternative-specific constants 的 logit，
* 与无 ASC 的 clogit + group() 不是同一个似然，系数不可逐位比对。
* 本机 DGP 实测 cmclogit price=-0.8865 / quality=0.9706，
* clogit price=-1.0667 / quality=1.1076 —— 同向但不同值，属预期。
scalar expected_wtp = -_b[quality]/_b[price]
if `has_wtp' {
    wtp price quality, delta
    matrix w = r(wtp)
    assert abs(w[1,1] - expected_wtp) < 1e-8
    wtp price quality, fieller
    wtp price quality, krinsky reps(1000) seed(1234)
    display "DCE_WTP_OK"
}
if `has_mixlogit' {
    mixlogit chosen price, group(grid) id(respondent) rand(quality) nrep(100)
    assert e(converged) == 1
    mixlpred double mixed_pr, nrep(100)
    bysort grid: egen double mixed_sum = total(mixed_pr)
    assert inrange(mixed_pr, 0, 1)
    assert abs(mixed_sum - 1) < 1e-6
    display "DCE_COMMUNITY_MIXLOGIT_OK"
}
if `has_lclogit' & `has_fmlogit' {
    * Two classes test the API; five classes require a larger application sample.
    gen male = mod(respondent, 2)
    lclogit chosen price quality, group(grid) id(respondent) ///
        ncl(2) seed(1234) membership(male) iterate(500)
    matrix list e(b)
    lclogitpr double Pr0, pr0
    lclogitpr double PrC, pr
    lclogitpr double H, up
    lclogitpr double G, cp
    foreach p in Pr0 PrC PrC1 PrC2 {
        assert inrange(`p', 0, 1)
        bysort grid: egen double sum_`p' = total(`p')
        assert abs(sum_`p' - 1) < 1e-6
    }
    foreach p in H1 H2 G1 G2 {
        assert inrange(`p', 0, 1)
        bysort respondent (`p'): assert abs(`p' - `p'[1]) < 1e-8
    }
    assert abs(H1 + H2 - 1) < 1e-6
    assert abs(G1 + G2 - 1) < 1e-6
    assert abs(Pr0 - (H1*PrC1 + H2*PrC2)) < 1e-6
    gen double b_price = _b[choice1:price]*G1 + _b[choice2:price]*G2
    gen double b_quality = _b[choice1:quality]*G1 + _b[choice2:quality]*G2
    gen double b_price_short = [choice1]price*G1 + [choice2]price*G2
    assert abs(b_price - b_price_short) < 1e-8
    egen byte person_tag = tag(respondent)
    summarize H1 H2 G1 G2 b_price b_quality if person_tag
    display "DCE_LCLOGIT_PROBABILITIES_OK"
}
if `has_probcalc' {
    * This is a distribution calculator, not a choice-model postestimator.
    probcalc b 10 0.5 exactly 5
    display "DCE_PROBCALC_DISTRIBUTION_ONLY_OK"
}
