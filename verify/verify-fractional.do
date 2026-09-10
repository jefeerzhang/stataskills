version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-fractional
* chapter:  fractional-response
* data:     sim:800
* checks:   fracreg-logit+fracreg-probit+betareg+boundaries+ame
* =========================
clear
set seed 20260912
set obs 800
gen id = ceil(_n/4)
gen double x = rnormal()
gen byte treated = runiform() > .5
gen double target = invlogit(-.3 + .7*x + .3*treated)
gen double beta_y = rbeta(target*8, (1-target)*8)
gen double share = beta_y
replace share = 0 if mod(_n,20) == 0
replace share = 1 if mod(_n,25) == 0
assert inrange(share,0,1) & !missing(share)
count if share == 0
assert r(N) > 0
count if share == 1
assert r(N) > 0
fracreg logit share c.x i.treated, vce(cluster id)
estimates store frac_logit
assert e(converged) == 1
assert e(N) == 800
predict double fractional_mean, cm
assert inrange(fractional_mean,0,1)
gen double analytic_dx = _b[x]*fractional_mean*(1-fractional_mean)
summarize analytic_dx, meanonly
scalar expected_ame = r(mean)
margins, dydx(x) predict(cm)
matrix ame = r(b)
assert abs(ame[1,1] - expected_ame) < 1e-6
margins, dydx(treated) predict(cm)
test x
display "FRACTIONAL_ENDPOINTS_AME_OK"

* RESET-type mean-specification diagnostic with generated index terms.
predict double link_index, xb
gen double index_sq = link_index^2
gen double index_cube = link_index^3
fracreg logit share c.x i.treated index_sq index_cube, vce(cluster id)
test index_sq index_cube
display "FRACTIONAL_SPECIFICATION_TEST_OK"
fracreg probit share c.x i.treated, vce(cluster id)
assert e(converged) == 1
predict double probit_mean, cm
assert inrange(probit_mean,0,1)
margins, dydx(x treated) predict(cm)

* Separate interior-only DGP, not a silent deletion of share endpoints.
assert beta_y > 0 & beta_y < 1
betareg beta_y c.x i.treated, vce(robust)
assert e(converged) == 1
predict double beta_mean, cmean
assert beta_mean > 0 & beta_mean < 1
margins, dydx(x treated) predict(cmean)
estat ic
display "FRACTIONAL_BETA_OK"
