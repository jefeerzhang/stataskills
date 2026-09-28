version 19.5
set more off

* ============================================================
* 用已生成的 .dta 做吸收型 vs 可逆多值路由演示
* 数据：data/did-routing/ 下两个 dta（先跑 build_did_routing.do）
* 产物：demo/logs/09_*.log 、demo/output/09_*.png
* ============================================================

* Resolve repo root (relative first; absolute fallback for non-root cwd)
local root "."
capture confirm file "`root'/data/did-routing/absorbing_staggered.dta"
if _rc {
    local root "c:/Users/jefeer/Downloads/stataskills"
}
local datadir "`root'/data/did-routing"
local outdir  "`root'/demo/output"
local logdir  "`root'/demo/logs"
capture mkdir "`outdir'"
capture mkdir "`logdir'"

capture confirm file "`datadir'/absorbing_staggered.dta"
if _rc {
    display as error "找不到 absorbing_staggered.dta"
    display as error "请先在仓库根目录运行: do data/did-routing/build_did_routing.do"
    exit 601
}

capture log close _all
log using "`logdir'/09_xtswitchdid_vs_xthdidregress.log", replace text

display as text _n "======== 场景 A：加载 absorbing_staggered.dta → xthdidregress ========"
use "`datadir'/absorbing_staggered.dta", clear
describe
tab cohort
tab year treat, row
xtset id year

display as text _n "--- A1 正确：xthdidregress aipw ---"
xthdidregress aipw (y) (treat), group(id)
estat aggregation, overall
estat aggregation, dynamic
estat aggregation, dynamic graph
graph export "`outdir'/09_absorbing_xthdid_dynamic.png", width(2000) replace
estat ptrends

display as text _n "--- A2 对照：同一吸收数据上 xtswitchdid（可跑，非默认）---"
xtswitchdid (y) (treat), group(id) neffects(4)
estat total
estat ptrends

display as text _n "======== 场景 B：加载 switching_multivalued.dta → xtswitchdid ========"
use "`datadir'/switching_multivalued.dta", clear
describe
tab dose
xtset id year

display as text _n "--- B1 正确：xtswitchdid ---"
xtswitchdid (y x1) (dose), group(id) neffects(3)
estat ptrends
estat paths
estat total
estat eventplot
graph export "`outdir'/09_switching_xtswitchdid_event.png", width(2000) replace

display as text _n "--- B2 反面：treat_bin（dose>0）→ xthdidregress ---"
capture noisily xthdidregress aipw (y) (treat_bin), group(id)
display as text "xthdidregress on treat_bin _rc = " _rc
if _rc == 498 {
    display as text "预期 r(498)：可逆处理不能硬套吸收型 staggered 命令"
}

display as text _n "--- B3 反面：treat_abs（ever-treated 偷看未来）---"
capture noisily xthdidregress aipw (y) (treat_abs), group(id)
display as text "xthdidregress on treat_abs _rc = " _rc
if _rc == 0 {
    estat aggregation, overall
    display as text "警告：能出数不等于识别对——treat_abs 偷看未来"
}

display as text _n "======== 路由小结 ========"
display as text "1) 二元吸收错时 → use absorbing_staggered.dta + xthdidregress aipw"
display as text "2) 多值可逆 → use switching_multivalued.dta + xtswitchdid"
display as text "DONE_ROUTING_DEMO"

log close
