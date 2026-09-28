version 19.5
* ============================================================
* Build switching_features.dta — xtswitchdid 功能点教学面板
* Stata 19.5 | seed 20260929
* ============================================================
clear all
set more off
set seed 20260929

if `"`outdir'"' == "" {
    local outdir "data/did-routing"
    capture confirm file "`outdir'/build_did_routing.do"
    if _rc {
        local outdir "c:/Users/jefeer/Downloads/stataskills/data/did-routing"
    }
}
capture mkdir "`outdir'"
confirm file "`outdir'/build_did_routing.do"

* 301 县会不整齐；用 280 县 × 16 年，嵌套 28 省（每省 10 县）
clear
set obs 4480
gen long id = ceil(_n/16)
bysort id: gen int year = 2009 + _n
gen byte province = ceil(id/10)

* typ 0-6
gen byte typ = mod(id, 7)
* 0 never at 0
* 1 0→1(2014)→2(2017) stay   switch-in
* 2 0→2(2013)→0(2019)         switch-in then return
* 3 start1→2(2015) stay         initial nonzero + in
* 4 never at 1                  control for typ3
* 5 start2→1(2016)→0(2021)     switch-out
* 6 never at 2                  control for typ5

gen byte dose = 0
replace dose = 0 if typ==0

replace dose = 0 if typ==1
replace dose = 1 if typ==1 & year>=2014
replace dose = 2 if typ==1 & year>=2017

replace dose = 0 if typ==2
replace dose = 2 if typ==2 & year>=2013
replace dose = 0 if typ==2 & year>=2019

replace dose = 1 if typ==3
replace dose = 2 if typ==3 & year>=2015

replace dose = 1 if typ==4

replace dose = 2 if typ==5
replace dose = 1 if typ==5 & year>=2016
replace dose = 0 if typ==5 & year>=2021

replace dose = 2 if typ==6

gen double x1 = rnormal()
gen double u = rnormal(0, 0.5) if year==2010
bysort id: replace u = u[1]
gen double y = 10 - 0.7*dose + 0.2*x1 + 0.15*province + u + rnormal(0, 1)

* 2020 缺失结局（非平衡）
replace y = . if year==2020
replace x1 = . if year==2020

label var id       "County id"
label var year     "Year"
label var province "Province (supergroup)"
label var typ      "Path type 0-6"
label var dose     "Discrete treatment 0-2"
label var x1       "Covariate"
label var y        "Outcome (true -0.7 per dose; missing in 2020)"
label var u        "Unit FE shock"

assert _N == 4480
assert inrange(dose, 0, 2)
isid id year
quietly count if typ==3 & year==2010 & dose==1
assert r(N) > 20
quietly count if typ==5 & year==2010 & dose==2
assert r(N) > 20
quietly count if typ==6 & year==2010 & dose==2
assert r(N) > 20
quietly count if typ==5 & year>=2021 & dose==0
assert r(N) > 0
quietly count if year==2020 & missing(y)
assert r(N) == 280

keep id year province typ dose x1 y
order id year province typ dose x1 y
compress
save "`outdir'/switching_features.dta", replace
display as text "SAVED `outdir'/switching_features.dta N=" _N
display as text "BUILD_SWITCHING_FEATURES_OK"
