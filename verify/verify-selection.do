version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-selection
* chapter:  selection-on-observables
* data:     selection/teaching-treatment.dta
* checks:   data-invariants+raw-imbalance+ipwra-atet+tebalance+overlap+psmatch+psmatch2-optional+ipw+nnmatch+ebalance-optional+tables
* ============================
set more off

* ---- 1. Data load and publication invariants ----
use "../selection/teaching-treatment", clear
ds
local actual `r(varlist)'
local expected id treat y x1 x2 x3 x4 x5 x6
assert "`actual'" == "`expected'"
assert _N == 2000
isid id
assert inlist(treat, 0, 1)
assert !missing(id, treat, y, x1, x2, x3, x4, x5, x6)
quietly summarize treat, meanonly
scalar treatment_rate = r(mean)
assert inrange(treatment_rate, 0.20, 0.30)
display "treatment_rate=" %9.6f treatment_rate

* ---- 2. Raw covariate imbalance and outcome difference ----
scalar max_abs_smd = 0
foreach v of varlist x1-x4 {
    quietly summarize `v' if treat == 1
    scalar mean1_`v' = r(mean)
    scalar sd1_`v' = r(sd)
    quietly summarize `v' if treat == 0
    scalar mean0_`v' = r(mean)
    scalar sd0_`v' = r(sd)
    scalar abs_smd_`v' = abs(mean1_`v' - mean0_`v') / ///
        sqrt((sd1_`v'^2 + sd0_`v'^2) / 2)
    scalar max_abs_smd = max(max_abs_smd, abs_smd_`v')
    display "raw_abs_smd_`v'=" %9.6f abs_smd_`v'
}
assert max_abs_smd > 0.1

quietly summarize y if treat == 1, meanonly
scalar raw_y_treated = r(mean)
quietly summarize y if treat == 0, meanonly
scalar raw_y_control = r(mean)
scalar raw_y_difference = raw_y_treated - raw_y_control
assert abs(raw_y_difference - 0.5) > 0.25
display "raw_y_difference=" %9.6f raw_y_difference

* ---- 3. Primary IPWRA ATET ----
teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
estimates store ipwra_atet
scalar ipwra_effect = _b[ATET:r1vs0.treat]
assert !missing(ipwra_effect)
assert abs(ipwra_effect - 0.5) <= 0.15
display "ipwra_atet=" %9.6f ipwra_effect

* ---- 4. Balance appendix, owned by the IPWRA estimate ----
display "=== BALANCE APPENDIX: IPWRA ATET ==="
tebalance summarize

* ---- 5. Propensity-score overlap diagnostic ----
teffects overlap

* ---- 6. Official propensity-score matching ATET ----
teffects psmatch (y) (treat x1 x2 x3 x4), atet nneighbor(1)
estimates store psmatch_atet
scalar psmatch_effect = _b[ATET:r1vs0.treat]
assert !missing(psmatch_effect)
display "psmatch_atet=" %9.6f psmatch_effect

* ---- 7. Optional community psmatch2 contracts ----
capture which psmatch2
local has_psmatch2 = (_rc == 0)
if !`has_psmatch2' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psmatch2__"
}
else {
    preserve
    psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1)
    scalar psmatch2_att = r(att)
    scalar psmatch2_seatt = r(seatt)
    assert !missing(psmatch2_att)
    assert !missing(psmatch2_seatt)
    confirm variable _weight
    confirm variable _support
    quietly count if _support == 1 & !missing(_weight)
    assert r(N) > 0
    restore

    preserve
    psmatch2 treat x1 x2 x3 x4, outcome(y) neighbor(1) ate
    scalar psmatch2_ate = r(ate)
    scalar psmatch2_att_from_ate = r(att)
    scalar psmatch2_seatt_from_ate = r(seatt)
    assert !missing(psmatch2_ate)
    assert !missing(psmatch2_att_from_ate)
    assert !missing(psmatch2_seatt_from_ate)
    confirm variable _weight
    confirm variable _support
    quietly count if _support == 1 & !missing(_weight)
    assert r(N) > 0
    restore
    estimates restore ipwra_atet
}

* ---- 8. Official inverse-probability-weighted ATET ----
teffects ipw (y) (treat x1 x2 x3 x4), atet
estimates store ipw_atet
scalar ipw_effect = _b[ATET:r1vs0.treat]
assert !missing(ipw_effect)
display "ipw_atet=" %9.6f ipw_effect

* ---- 9. Official covariate nearest-neighbor ATET ----
teffects nnmatch (y x1 x2 x3 x4) (treat), atet nneighbor(1) ///
    metric(mahalanobis) biasadj(x1 x2 x3 x4) ///
    vce(robust, nn(2)) osample(nn_osample)
estimates store nnmatch_atet
scalar nnmatch_effect = _b[ATET:r1vs0.treat]
assert !missing(nnmatch_effect)
confirm variable nn_osample
assert inlist(nn_osample, 0, 1)
display "nnmatch_atet=" %9.6f nnmatch_effect

* ---- 10. Optional community entropy-balancing contracts ----
capture which ebalance
local has_ebalance = (_rc == 0)
if !`has_ebalance' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ebalance__"
}
else {
    preserve
    ebalance treat x1 x2 x3 x4, targets(1)
    assert e(convg) == 1
    tempvar esample_default
    generate byte `esample_default' = e(sample)
    confirm variable _webal
    assert !missing(_webal) if `esample_default'
    assert _webal >= 0 if `esample_default'
    drop _webal

    ebalance treat x1 x2 x3 x4, targets(1) generate(ebw_verify)
    assert e(convg) == 1
    tempvar esample_named
    generate byte `esample_named' = e(sample)
    confirm variable ebw_verify
    assert !missing(ebw_verify) if `esample_named'
    assert ebw_verify >= 0 if `esample_named'
    restore
    estimates restore ipwra_atet
}

* ---- 11. Original-scale table for the four built-in estimators ----
estimates restore ipwra_atet
estimates table ipwra_atet psmatch_atet ipw_atet nnmatch_atet, ///
    b(%9.4f) se(%9.4f)
