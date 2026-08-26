version 19.5

* build-teaching.do
* Purpose: generate the stata-selection teaching dataset.
* True ATET = 0.5 (constant treatment effect).
* Design: treatment and Y(0) share pretreatment observables, creating
*         selection-on-observables bias in the raw mean difference.
*         Treatment is not driven by an unobserved variable that also
*         affects the potential outcomes.
* Output: data/selection/teaching-treatment.dta

clear all
set seed 20260825
set obs 2000

* === 1. Pretreatment observable covariates ===
gen x1 = rnormal()
gen x2 = rnormal()
gen x3 = runiform()
gen x4 = rnormal()
gen x5 = runiform()
gen x6 = rnormal()

* === 2. True propensity score and Bernoulli treatment assignment ===
* Intercept -1.25 calibrates the treatment rate to about 25%.
gen double eta = -1.25 + 0.45*x1 + 0.55*x2 + 0.35*(x3 - 0.5) - 0.40*x4
gen double ps_true = invlogit(eta)
assert !missing(ps_true)
assert ps_true > 0 & ps_true < 1

gen treat = runiform() < ps_true
quietly summarize treat, meanonly
scalar treat_rate = r(mean)
assert inrange(treat_rate, 0.20, 0.30)
display "Treatment rate = " %6.3f treat_rate " (prespecified range: 0.20-0.30)"

* === 3. Potential outcomes ===
* Y(0) and treatment assignment share x1-x4; noise affects outcomes only.
gen noise = rnormal()
gen y0 = 1 + 0.70*x1 + 0.80*x2 + 0.50*x3 - 0.60*x4 + noise
gen tau = 0.5
gen y1 = y0 + tau
assert tau == 0.5

* === 4. Observed outcome and construction checks ===
gen y = y0 + treat*tau
gen id = _n
assert _N == 2000
assert !missing(x1, x2, x3, x4, x5, x6)
assert !missing(id, treat, y, y0, y1, tau, eta, noise)
assert inlist(treat, 0, 1)

* === 5. Published variables and English labels ===
keep id treat y x1-x6
order id treat y x1-x6
sort id

label variable id    "Observation identifier"
label variable treat "Treatment indicator (true ATET = 0.5)"
label variable y     "Observed outcome"
label variable x1    "Pretreatment covariate 1"
label variable x2    "Pretreatment covariate 2"
label variable x3    "Pretreatment covariate 3"
label variable x4    "Pretreatment covariate 4"
label variable x5    "Pretreatment covariate 5"
label variable x6    "Pretreatment covariate 6"

* === 6. Teaching diagnostic: unadjusted mean difference ===
quietly summarize y if treat == 1, meanonly
scalar mean_treated = r(mean)
quietly summarize y if treat == 0, meanonly
scalar mean_control = r(mean)
scalar raw_difference = mean_treated - mean_control
display "Unadjusted mean difference (treated - control) = " %6.3f raw_difference

* === 7. Smoke test: IPWRA ATET within prespecified tolerance ===
teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
scalar atet_hat = _b[ATET:r1vs0.treat]
display "IPWRA ATET = " %6.3f atet_hat " (true value 0.5; prespecified tolerance +/-0.15)"
assert abs(atet_hat - 0.5) <= 0.15

* === 8. Final publication constraints ===
* Check the exact release schema and exclusions before writing the file.
unab published : _all
assert "`published'" == "id treat y x1 x2 x3 x4 x5 x6"
capture confirm variable oracle
assert _rc != 0

* === 9. Save only after every publication constraint passes ===
capture mkdir "data"
capture mkdir "data/selection"
save "data/selection/teaching-treatment.dta", replace
