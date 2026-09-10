version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-limited-dependent
* chapter:  censoring-hurdle-sample-selection
* data:     sim:1200
* checks:   tobit+churdle+two-part+heckman+heckprobit
* =========================
clear
set seed 20260913
set obs 1200
gen double x = rnormal()
gen double z = rnormal()
gen double u = rnormal()
gen double v = .5*u + sqrt(.75)*rnormal()
gen double latent = .3 + .7*x + u
gen double censored = max(0,latent)
assert censored >= 0 & censored < .
count if censored == 0
assert r(N) > 0
tobit censored c.x, ll(0) vce(robust)
assert e(converged) == 1
predict double observed_mean, ystar(0,.)
predict double positive_mean, e(0,.)
predict double positive_prob, pr(0,.)
assert abs(observed_mean-positive_prob*positive_mean) < 1e-7
margins, dydx(x) predict(ystar(0,.))
margins, dydx(x) predict(pr(0,.))
display "LIMITED_TOBIT_TARGETS_OK"

gen byte participates = runiform() < normal(.2 + .3*x + .6*z)
gen double spending = participates*exp(.4 + .5*x + .5*rnormal())
churdle exponential spending c.x, select(x z) ll(0) vce(robust)
assert e(converged) == 1
predict double hurdle_mean, ystar
assert hurdle_mean > 0 & hurdle_mean < .
margins, dydx(x) predict(ystar)
display "LIMITED_HURDLE_OK"

* Two-part expectation: P(y>0|x,z) * E(y|y>0,x).
logit participates c.x c.z, vce(robust)
predict double participation_prob, pr
glm spending c.x if participates, family(gamma) link(log) vce(robust)
predict double positive_spend, mu
gen double two_part_mean = participation_prob*positive_spend
assert two_part_mean > 0 & two_part_mean < .
display "LIMITED_TWO_PART_OK"

gen byte selected = (.2 + .4*x + .8*z + v > 0)
gen double outcome = latent if selected
assert missing(outcome) if !selected
assert !missing(outcome) if selected
heckman outcome c.x, select(selected = c.x c.z) vce(robust)
estimates store selection_ml
assert e(converged) == 1
scalar ml_N = e(N)
scalar ml_b_x = _b[outcome:x]
test [selected]z
test /athrho = 0
predict double selected_mean, ycond
predict double population_mean, xb
assert selected_mean < . & population_mean < .
margins, dydx(x) predict(ycond)
heckman outcome c.x, select(selected = c.x c.z) twostep
assert e(N) == 1200
* 两步与 ML 的交叉不变量：样本量与方向必须一致（数值可不同，两步非有效）。
* 只查 e(N) 抓不到样本被悄悄丢掉或主方程系数反号。
assert e(N) == ml_N
assert !missing(_b[outcome:x])
assert sign(_b[outcome:x]) == sign(ml_b_x)
display "LIMITED_HECKMAN_OK"

gen byte binary_outcome = (latent > 0) if selected
heckprobit binary_outcome c.x, select(selected = c.x c.z) vce(robust)
assert e(converged) == 1
test /athrho = 0
predict double p_joint, p11
predict double p_select, psel
predict double p_cond, pcond
assert inrange(p_joint,0,1) & inrange(p_select,0,1) & inrange(p_cond,0,1)
assert abs(p_joint-p_select*p_cond) < 1e-7
margins, dydx(x) predict(pcond)
display "LIMITED_HECKPROBIT_OK"
