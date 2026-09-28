version 19.5
set more off

* ============================================================
* xtswitchdid 功能点全演示（官方手册能力清单）
* 数据：data/did-routing/switching_features.dta
* 产物：demo/logs/10_*.log 、demo/output/10_*.png
* ============================================================

local root "."
capture confirm file "`root'/data/did-routing/switching_features.dta"
if _rc {
    local root "c:/Users/jefeer/Downloads/stataskills"
}
local datadir "`root'/data/did-routing"
local outdir  "`root'/demo/output"
local logdir  "`root'/demo/logs"
capture mkdir "`outdir'"
capture mkdir "`logdir'"

capture confirm file "`datadir'/switching_features.dta"
if _rc {
    display as error "找不到 switching_features.dta"
    display as error "请先运行: do data/did-routing/build_switching_features.do"
    exit 601
}

capture log close _all
log using "`logdir'/10_xtswitchdid_features.log", replace text

use "`datadir'/switching_features.dta", clear
describe
tab typ
tab dose
tab year, missing
xtset id year

* ============================================================
display as text _n "======== F1 基线：离散多值 + 可切换 + 协变量 ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(6)
estat ptrends
estat total
estat eventplot
graph export "`outdir'/10_baseline_event.png", width(2000) replace
display as text "F1_OK"

* ============================================================
display as text _n "======== F2 初始处理非零：限制 typ 3/4（初始=1）========"
* ============================================================
* 仅保留初始 dose=1 的类型，演示「不必从 0 起步」
preserve
keep if inlist(typ, 3, 4)
xtset id year
xtswitchdid (y x1) (dose), group(id) neffects(4)
estat total
display as text "F2_OK"
restore

* ============================================================
display as text _n "======== F3 switchgroup(in) 只要升档 switcher ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(5) switchgroup(in)
estat total
display as text "F3_OK"

* ============================================================
display as text _n "======== F4 switchgroup(out) 只要降档（首次切换向下）========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(5) switchgroup(out)
estat total
display as text "F4_OK"

* ============================================================
display as text _n "======== F5 controlgroup(never) 仅从未切换对照 ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(5) controlgroup(never)
estat total
display as text "F5_OK"

* ============================================================
display as text _n "======== F6 path-specific：路径特定效应 ========"
* ============================================================
quietly xtswitchdid (y x1) (dose), group(id) neffects(6)
estat paths, pathlen(6) generate(featpath)
* 找一条频数最高的路径指示变量再估
quietly tab _did_paths
xtswitchdid (y x1) (dose), group(id) path(featpath1) neffects(5)
estat total
display as text "F6_OK"
capture drop featpath* _did_paths

* ============================================================
display as text _n "======== F7 supergroup(province)：省内比较 ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) supergroup(province) neffects(5)
estat total
display as text "F7_OK"

* ============================================================
display as text _n "======== F8 raw vs normalized ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(4)
estat total
estimates store norm4
xtswitchdid (y x1) (dose), group(id) neffects(4) raw
estat total
display as text "F8_OK"

* ============================================================
display as text _n "======== F9 commonswitchers：各暴露期同一批 switcher ========"
* ============================================================
xtswitchdid (y x1) (dose), group(id) neffects(5) commonswitchers
estat total
display as text "F9_OK"

* ============================================================
display as text _n "======== F10 非平衡面板（2020 缺失）已在 F1；隔年 delta(2) ========"
* ============================================================
preserve
keep if mod(year, 2)==0
xtset id year, delta(2)
xtswitchdid (y x1) (dose), group(id) neffects(4)
estat total
display as text "F10_OK"
restore

display as text _n "======== 功能点小结 ========"
display as text "F1 multivalued switching | F2 initial nonzero | F3 switch in"
display as text "F4 switch out | F5 never controls | F6 path-specific"
display as text "F7 supergroup | F8 raw | F9 commonswitchers | F10 delta(2)"
display as text "DONE_FEATURES_DEMO"

log close
