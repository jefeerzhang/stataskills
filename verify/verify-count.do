version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-count
* chapter:  count-ppml
* data:     sim:600
* checks:   poisson+nbreg+zip+zinb+ppmlhdfe
* =========================
clear
set seed 20260911
set obs 600
gen id = ceil(_n/6)
bysort id: gen t = _n
gen double x = rnormal()
gen double z = rnormal()
gen double exposure = 1 + runiform()*2
gen double log_exposure = ln(exposure)
gen double mu = exposure*exp(.3 + .4*x)
gen y = rpoisson(mu)
assert y >= 0 & y == floor(y) & !missing(y)
assert exposure > 0 & exposure < .
poisson y c.x, exposure(exposure) vce(cluster id)
estimates store pois
assert e(converged) == 1
scalar b_exp = _b[x]
predict double mean_count, n
predict double rate, ir
assert abs(mean_count - rate*exposure) < 1e-7
margins, dydx(x) predict(n)
test x
poisson y c.x, offset(log_exposure) vce(cluster id)
assert abs(_b[x] - b_exp) < 1e-8
* GOF uses the count likelihood; its p-value does not validate robust PPML.
poisson y c.x, exposure(exposure)
estat gof
gen double pearson_sq = (y - mean_count)^2/mean_count
summarize pearson_sq
display "COUNT_EXPOSURE_OK"

gen double hetero_mu = mu*rgamma(2,.5)
gen y_over = rpoisson(hetero_mu)
nbreg y_over c.x, exposure(exposure) vce(cluster id)
assert e(converged) == 1
predict double nb_mean, n
assert nb_mean > 0 & nb_mean < .
margins, dydx(x) predict(n)
display "COUNT_NB_OK"

gen byte structural_zero = runiform() < invlogit(-.7 + .6*z)
gen y_zero = cond(structural_zero, 0, y_over)
zip y_zero c.x, inflate(z) exposure(exposure) vce(cluster id)
estimates store zip_model
assert e(converged) == 1
predict double zip_p0, pr(0)
assert inrange(zip_p0, 0, 1)
margins, dydx(x) predict(n)
zinb y_zero c.x, inflate(z) exposure(exposure) vce(cluster id)
estimates store zinb_model
assert e(converged) == 1
predict double zinb_p0, pr(0)
assert inrange(zinb_p0, 0, 1)
estat ic
display "COUNT_ZERO_MODELS_OK"

* PPML is also a conditional-mean estimator for noninteger nonnegative y.
gen double value = y*exp(.15*z)
poisson value c.x i.id i.t, vce(cluster id)
scalar b_dummy = _b[x]
assert e(converged) == 1
cap which ftools
local has_ftools = (_rc == 0)
if !`has_ftools' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ftools__"
}
cap which reghdfe
local has_reghdfe = (_rc == 0)
if !`has_reghdfe' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__reghdfe__"
}
cap which ppmlhdfe
local has_ppmlhdfe = (_rc == 0)
if !`has_ppmlhdfe' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__ppmlhdfe__"
}
if `has_ftools' & `has_reghdfe' & `has_ppmlhdfe' {
    ppmlhdfe value c.x, absorb(id t) vce(cluster id) d(fe_sum)
    assert e(converged) == 1
    assert abs(_b[x] - b_dummy) < 1e-5
    predict double ppml_mu if e(sample), mu
    assert ppml_mu > 0 & ppml_mu < . if e(sample)
    display "COUNT_PPML_EQUIVALENCE_OK"
    preserve
    replace value = 0 if id == 100
    ppmlhdfe value c.x, absorb(id t) vce(cluster id) d(sep_fe)
    assert e(converged) == 1
    assert e(N) < 600
    assert !e(sample) if id == 100
    predict double sep_mu if e(sample), mu
    assert missing(sep_mu) if id == 100
    display "COUNT_PPML_SEPARATION_OK"
    restore
}
