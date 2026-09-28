version 19.5
* ============================================================
* Build project-generated DID routing teaching datasets.
* Stata 19.5 | seed 20260928
* Output:
*   data/did-routing/absorbing_staggered.dta   (场景 A)
*   data/did-routing/switching_multivalued.dta (场景 B)
* ============================================================
clear all
set more off
set seed 20260928

* Default: repo-relative path (run from repo root, same as data/selection/).
* Override for non-root cwd: do build_did_routing.do, outdir("C:/full/path/data/did-routing")
if `"`outdir'"' == "" {
    local outdir "data/did-routing"
    capture confirm file "`outdir'/build_did_routing.do"
    if _rc {
        local outdir "c:/Users/jefeer/Downloads/stataskills/data/did-routing"
    }
}
capture mkdir "`outdir'"
confirm file "`outdir'/build_did_routing.do"

* ======================== 场景 A ========================
* 400 县 × 12 年；二元吸收错时；真值开通后约 ATT=2 + 0.15×暴露期
clear
set obs 4800
gen long id = ceil(_n/12)
bysort id: gen int year = 2009 + _n

gen byte cohort = 0
replace cohort = 1 if mod(id, 5) == 1
replace cohort = 2 if mod(id, 5) == 2
gen byte treat = (cohort==1 & year>=2014) | (cohort==2 & year>=2017)

gen double u = rnormal(0, 1) if year==2010
bysort id: replace u = u[1]
gen double y = 10 + 0.3*(year-2010) + u ///
    + cond(cohort==1 & year>=2014, 2.0 + 0.15*(year-2014), 0) ///
    + cond(cohort==2 & year>=2017, 2.0 + 0.15*(year-2017), 0) ///
    + rnormal(0, 1)

label var id     "County id"
label var year   "Year"
label var cohort "Adoption cohort: 0 never, 1 from 2014, 2 from 2017"
label var treat  "Absorbing treatment indicator"
label var u      "Unit FE shock (draw once)"
label var y      "Outcome (true post ATT ~ 2 + 0.15*exposure)"

* invariants
assert _N == 4800
quietly count if treat==1
assert r(N) == 1040
quietly summarize treat, meanonly
assert reldif(r(mean), 0.21666667) < 1e-6
isid id year
keep id year cohort treat y
order id year cohort treat y
compress
save "`outdir'/absorbing_staggered.dta", replace
display as text "SAVED `outdir'/absorbing_staggered.dta  N=" _N

* ======================== 场景 B ========================
* 250 县 × 20 年；dose 0/1/2 可逆；真值每单位 dose ≈ -0.8
clear
set seed 20260928
set obs 5000
gen long id = ceil(_n/20)
bysort id: gen int year = 2005 + _n

gen byte dose = 0
replace dose = 1 if year>=2012 & mod(id, 4)==1
replace dose = 2 if year>=2015 & mod(id, 4)==1
replace dose = 0 if year>=2018 & mod(id, 4)==1
replace dose = 1 if year>=2014 & mod(id, 5)==2
replace dose = 2 if year>=2016 & mod(id, 7)==3

gen double x1 = rnormal()
gen double y = 10 - 0.8*dose + 0.2*x1 + rnormal(0, 1)

* 教学用反面变量（不当作真处理，仅供错误编码演示）
* treat_abs = 截至当期是否曾 dose>0：首次处理后永久置 1（掩盖撤销），不是偷看未来
gen byte treat_bin = (dose > 0)
bysort id (year): gen byte treat_abs = sum(dose > 0) > 0

label var id        "County id"
label var year      "Year"
label var dose      "Multivalued switching treatment 0/1/2"
label var x1        "Covariate"
label var y         "Outcome (true effect -0.8 per dose unit)"
label var treat_bin "WRONG coding: dose>0 contemporaneous"
label var treat_abs "WRONG coding: sticky ever-treated (masks switch-out)"

assert _N == 5000
quietly tab dose
assert inrange(dose, 0, 2)
isid id year
* 确认存在 switch-out：曾 dose>0 后又回到 0（treat_abs 仍为 1）
quietly count if dose==0 & treat_abs==1
assert r(N) == 352
* 不是偷看未来：首次处理前不存在 treat_abs==1
bysort id (year): gen int fyr = cond(sum(dose>0)==1 & dose>0, year, .)
bysort id: egen int first_treat_year = min(fyr)
quietly count if treat_abs==1 & year < first_treat_year
assert r(N) == 0
drop fyr first_treat_year
keep id year dose x1 y treat_bin treat_abs
order id year dose x1 y treat_bin treat_abs
compress
save "`outdir'/switching_multivalued.dta", replace
display as text "SAVED `outdir'/switching_multivalued.dta  N=" _N

display as text "BUILD_DID_ROUTING_OK"
