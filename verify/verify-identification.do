version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-identification
* chapter:  identification-common-assumptions
* data:     sim:2000x6
* checks:   consistency+SUTVA+exchangeability+positivity+estimand+power-precision-separation
* ============================
set more off
set seed 20260826

* ---- 1. Randomized DGP with a fixed individual treatment effect ----
clear
set obs 2000
generate long id = _n
generate double y0 = rnormal()
generate double y1 = y0 + 0.5
generate byte treat = (runiform() < 0.5)
generate double tau = y1 - y0
generate double y = y0 + treat * tau

assert _N == 2000
isid id
ds
local actual `r(varlist)'
local expected id y0 y1 treat tau y
assert "`actual'" == "`expected'"

* ---- 2. Consistency and SUTVA/no-interference DGP constraint ----
assert y == cond(treat == 1, y1, y0)
assert abs(tau - 0.5) < 1e-12
* Each row's potential outcomes depend only on that row's treatment.
* This is a no-interference constraint imposed by the DGP, not a statistical proof.
display "no_interference_status=DGP constraint; not statistically proven"

* ---- 3. Random assignment, exchangeability example, and positivity ----
assert inlist(treat, 0, 1)
quietly summarize treat, meanonly
scalar treatment_rate = r(mean)
assert inrange(treatment_rate, 0.45, 0.55)
assert treatment_rate > 0 & treatment_rate < 1
display "randomized_treatment_rate=" %9.6f treatment_rate

quietly summarize y0 if treat == 1, meanonly
scalar y0_treated = r(mean)
quietly summarize y0 if treat == 0, meanonly
scalar y0_control = r(mean)
scalar realized_y0_difference = y0_treated - y0_control
assert abs(realized_y0_difference) < 0.15
display "randomization_supportive_y0_difference=" %9.6f realized_y0_difference

* ---- 4. ATE and ATET estimands, plus randomized numerical recovery ----
quietly summarize tau, meanonly
scalar known_ate = r(mean)
assert abs(known_ate - 0.5) < 1e-12
quietly summarize tau if treat == 1, meanonly
scalar known_atet = r(mean)
assert abs(known_atet - 0.5) < 1e-12

display "estimand_label=ATE; target=all units; known_value=" %9.6f known_ate
display "estimand_label=ATET; target=treated units; known_value=" %9.6f known_atet
display "estimand_label=LATE; target=compliers under a valid IV design; not estimated here"
display "estimand_label=local effect; target=design-defined local population; not estimated here"

regress y treat, vce(robust)
scalar randomized_atet_hat = _b[treat]
assert !missing(randomized_atet_hat)
assert abs(randomized_atet_hat - known_atet) <= 0.15
display "randomized_atet_recovery=" %9.6f randomized_atet_hat

* ---- 5. Power and precision are not identification conditions ----
scalar precision_se = _se[treat]
scalar precision_ci_low = _b[treat] - invnormal(0.975) * precision_se
scalar precision_ci_high = _b[treat] + invnormal(0.975) * precision_se
scalar power_mde_80 = (invnormal(0.975) + invnormal(0.80)) * precision_se
assert precision_se > 0
assert precision_ci_low < precision_ci_high
assert power_mde_80 > 0
display "precision_only_se=" %9.6f precision_se
display "precision_only_ci95=[" %9.6f precision_ci_low ", " ///
    %9.6f precision_ci_high "]"
display "power_only_mde80=" %9.6f power_mde_80
display "power_precision_status=reported separately; not identification conditions"
