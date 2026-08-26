* build-teaching.do
* 用途: 生成 stata-selection 教学版数据
* 真 ATET = 0.5（固定处理效应）
* 设计: treatment 与 Y(0) 共享处理前可观测协变量，制造原始差异偏误
*       treatment 不受同时影响潜在结果的未观测变量驱动
* 输出: data/selection/teaching-treatment.dta

version 19.5
clear all
set seed 20260825
set obs 2000

* === 1. 处理前可观测协变量 ===
gen x1 = rnormal()
gen x2 = rnormal()
gen x3 = runiform()
gen x4 = rnormal()
gen x5 = runiform()
gen x6 = rnormal()

* === 2. 真实倾向得分与 Bernoulli 处理分配 ===
* 截距 -1.25 将处理率校准到约 25%
gen double eta = -1.25 + 0.45*x1 + 0.55*x2 + 0.35*(x3 - 0.5) - 0.40*x4
gen double ps_true = invlogit(eta)
assert !missing(ps_true)
assert ps_true > 0 & ps_true < 1

gen treat = runiform() < ps_true
quietly summarize treat, meanonly
scalar treat_rate = r(mean)
assert inrange(treat_rate, 0.20, 0.30)
display "处理率 = " %6.3f treat_rate "（预设区间：0.20–0.30）"

* === 3. 潜在结果 ===
* Y(0) 与处理分配共享 x1-x4；noise 只影响结果，不影响 treatment
gen noise = rnormal()
gen y0 = 1 + 0.70*x1 + 0.80*x2 + 0.50*x3 - 0.60*x4 + noise
gen tau = 0.5
gen y1 = y0 + tau
assert tau == 0.5

* === 4. 观测结果与构建断言 ===
gen y = y0 + treat*tau
gen id = _n
assert _N == 2000
assert !missing(x1, x2, x3, x4, x5, x6)
assert !missing(id, treat, y, y0, y1, tau, eta, noise)
assert inlist(treat, 0, 1)

* === 5. 发布变量与标签 ===
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

* === 6. 教学对照：未调整均值差 ===
quietly summarize y if treat == 1, meanonly
scalar mean_treated = r(mean)
quietly summarize y if treat == 0, meanonly
scalar mean_control = r(mean)
scalar raw_difference = mean_treated - mean_control
display "未调整均值差（处理组 - 对照组） = " %6.3f raw_difference

* === 7. 烟测：IPWRA ATET 应在预设容差内 ===
teffects ipwra (y x1 x2 x3 x4) (treat x1 x2 x3 x4), atet
scalar atet_hat = _b[ATET:r1vs0.treat]
display "IPWRA ATET = " %6.3f atet_hat "（真值 0.5；预设容差 ±0.15）"
assert abs(atet_hat - 0.5) <= 0.15

* === 8. 烟测通过后保存 ===
capture mkdir "data/selection"
save "data/selection/teaching-treatment.dta", replace
