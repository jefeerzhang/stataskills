*=============================================================================
* 10_xtswitchdid_features.do
* REPORT-10 讲稿的演示脚本：xtswitchdid 选定之后，10 个功能开关怎么设
*
* 数据：data/did-routing/switching_features.dta（seed 20260929）
* 真值（见 build_switching_features.do）：
*   处理效应 tau = -dev * (rate + ramp * min(ell,4))
*    rate：早批升档 0.70 / 晚批升档 0.55 / 早批降档 0.45 / 晚批降档 0.30
*    ramp：早批 0.20 / 晚批 0.12（按暴露期累积，4 期封顶）
*    dev = 当期 dose 相对初始水平的偏离
*
* 约定：凡是「用/不用某个开关」的对照，两侧 neffects 必须相同，
*       否则差别里混进了窗口长度的变化，说不清是哪个开关在起作用。
*=============================================================================
version 19.5
clear all
set more off
set linesize 120

local root "C:/Users/jefeer/Downloads/stataskills"
local out  "`root'/demo/output"
capture log close _all
log using "`root'/demo/logs/10_xtswitchdid_features.log", replace text

use "`root'/data/did-routing/switching_features.dta", clear

*-----------------------------------------------------------------------------
* 0. 课前：数据长什么样
*-----------------------------------------------------------------------------
display as text _n "########## 0. 数据概览 ##########"
xtset id year

generate byte switcher = inlist(typ, 3, 4, 5, 6, 7)
label var switcher "该县是否切换过处理（1=是）"

display as text _n "--- 0a. 每类路径的 dose 均值与县数 ---"
tabulate typ, summarize(dose)
display as text _n "--- 0b. 切换组 vs never 组 ---"
tabulate switcher, missing
display as text _n "--- 0c. 2020 年结局缺失 ---"
tabulate year, missing
display as text _n "--- 0d. 初始处理水平 × 切换方向 ---"
generate byte initsym = .
replace initsym = 0 if inlist(typ, 0, 1, 2)      // 从不切换
replace initsym = 1 if inlist(typ, 3, 4, 5)      // 首次切换方向＝升档
replace initsym = -1 if inlist(typ, 6, 7)        // 首次切换方向＝降档
label define initsym 0 "never" 1 "switcher-in" -1 "switcher-out"
label values initsym initsym
tabulate initsym, summarize(dose)

display as text _n "--- 0e. 真值画像：tau 按 typ × 暴露期 ---"
generate int ell = 0
replace ell = year - f + 1 if f > 0 & year >= f
label var ell "暴露期（首次切换当年为第 1 期）"
table (ell) (typ) if ell > 0, statistic(mean tau) nformat(%6.2f) nototals
display as text _n "--- 0f. 真值：每个 typ 的 rate / ramp / 首次切换年 ---"
preserve
bysort id: keep if _n == 1
table (typ), statistic(mean rate) statistic(mean ramp) statistic(mean f) statistic(mean d0) nototals
restore

*=============================================================================
* 第 0 节  传统方法在这份数据上会怎样（学生要看的对照）
*=============================================================================
display as text _n "########## 0. 传统方法对照 ##########"

*--- TD1：把多值处理粗暴二值化，直接塞给 xthdidregress ---
display as text _n "--- TD1: treat_bin = (dose>0) 进 xthdidregress ---"
generate byte treat_bin = (dose > 0)
capture noisily xthdidregress aipw (y x1) (treat_bin), group(id)
display as text "TD1_rc = " _rc
display as text "（失败原因：2010 年就有县 dose>0，传统二元 DID 要求首期无人受处理）"

*--- TD2：换一个「能跑」的二元编码 —— 吸收错时 ever-treated ---
*    定义：首次切换当年起 treat_ever=1，之前为 0。这是标准吸收、错时二元处理。
display as text _n "--- TD2: treat_ever = 吸收错时二元处理（首次切换年 >= 2012）---"
generate byte treat_ever = 0
replace treat_ever = 1 if inlist(typ, 3, 4, 7) & year >= 2012
replace treat_ever = 1 if inlist(typ, 5, 6)    & year >= 2017

* 这个编码在说谎：降档县被标成「已处理」
display as text "二元编码下被标「已处理」但 dose 其实低于初始水平的观测数："
count if treat_ever == 1 & dose < d0
display as text "其中降档县（typ6/typ7）占："
count if treat_ever == 1 & dose < d0 & inlist(typ, 6, 7)

display as text _n "--- TD2b. xthdidregress 估计（会跑出数来）---"
capture noisily xthdidregress aipw (y x1) (treat_ever), group(id)
display as text "TD2_rc = " _rc
display as text _n "--- TD2c. 同样的编码，放进 xtswitchdid 也不行（它只能识别处理变量本身）---"

*--- TD3：最朴素的 TWFE —— 把 dose 当成连续处理塞进双向固定效应 ---
display as text _n "--- TD3: areg y dose x1 i.year, absorb(id) ---"
areg y dose x1 i.year, absorb(id) cluster(id)
display as text "TD3 OK"

*=============================================================================
* 第 1 节  F1 基线：默认设定
*=============================================================================
display as text _n "########## F1 基线 ##########"

display as text _n "--- F1a. neffects 阶梯（窗口长度怎么影响每单位总效应）---"
foreach k in 4 6 8 10 12 {
    display as text _n ">>> neffects(`k')"
    quietly xtswitchdid (y x1) (dose), group(id) neffects(`k')
    estat total
}

display as text _n "--- F1b. 基准设定 neffects(6)，完整输出 ---"
xtswitchdid (y x1) (dose), group(id) neffects(6)
display as text _n "--- F1c. estat ptrends ---"
estat ptrends
display as text _n "--- F1d. estat eventplot ---"
estat eventplot
capture graph export "`out'/10_f1_eventplot.png", replace width(1400)
display as text _n "--- F1e. estat total ---"
estat total
display as text "F1_OK"

*=============================================================================
* 第 2 节  F2 初始处理非零：处理不必从 0 起步
*=============================================================================
display as text _n "########## F2 初始处理非零 ##########"
preserve
keep if d0 > 0                              // 初始水平只有 1 和 2，没有 0
xtset id year
display as text _n "--- F2a. 子样本构成 ---"
tabulate typ, summarize(dose)
display as text _n "--- F2b. 估计（neffects(6)）---"
xtswitchdid (y x1) (dose), group(id) neffects(6)
estat total
display as text "F2_OK"
restore

*=============================================================================
* 第 3 节  F3 只用升档 switcher
*=============================================================================
display as text _n "########## F3 switchgroup(in) ##########"
xtswitchdid (y x1) (dose), group(id) neffects(6) switchgroup(in)
estat total
display as text "F3_OK"

*=============================================================================
* 第 4 节  F4 只用降档 switcher
*=============================================================================
display as text _n "########## F4 switchgroup(out) ##########"
xtswitchdid (y x1) (dose), group(id) neffects(6) switchgroup(out)
estat total
display as text "F4_OK"

*=============================================================================
* 第 5 节  F5 对照池只用 never-switcher
*=============================================================================
display as text _n "########## F5 controlgroup(never) ##########"
xtswitchdid (y x1) (dose), group(id) neffects(6) controlgroup(never)
estat total
display as text "F5_OK"

*=============================================================================
* 第 6 节  F6 路径特定效应
*=============================================================================
display as text _n "########## F6 path() ##########"
display as text _n "--- F6a. 路径分布 pathlen(6) ---"
estat paths, pathlen(6)
display as text _n "--- F6b. 生成路径指示变量 ---"
quietly estat paths, pathlen(6) generate(featpath)
describe featpath*
display as text _n "--- F6c. pathlen(4) 会把哪些县并到一起 ---"
estat paths, pathlen(4)
display as text _n "--- F6d. 只估第 1 条路径 ---"
xtswitchdid (y x1) (dose), group(id) neffects(6) path(featpath1)
estat total
display as text "F6_OK"

*=============================================================================
* 第 7 节  F7 只在同一省（超组）内比较
*=============================================================================
display as text _n "########## F7 supergroup(province) ##########"
xtswitchdid (y x1) (dose), group(id) neffects(6) supergroup(province)
estat total
display as text "F7_OK"

*=============================================================================
* 第 8 节  F8 原始效应（raw）与归一化效应对照
*=============================================================================
display as text _n "########## F8 raw ##########"
display as text _n "--- F8a. 原始（未归一化）暴露期效应 ---"
xtswitchdid (y x1) (dose), group(id) neffects(6) raw
estat total
display as text _n "--- F8b. estat total 在 raw 与默认下是否相同 ---"
quietly xtswitchdid (y x1) (dose), group(id) neffects(6)
estat total

display as text _n "--- F8c. 归一化的分母到底是什么？单一路径子样本验算 ---"
display as text "子样本 typ0(never,初始 0) + typ3(0→1 @2012)，dev 恒等于 1"
display as text "预测：raw / normalized = 1, 2, 3, 4, 5, 6"
preserve
keep if inlist(typ, 0, 3)
xtset id year
quietly xtswitchdid (y x1) (dose), group(id) neffects(6) raw
display as text _n ">>> A1. raw"
xtswitchdid (y x1) (dose), group(id) neffects(6) raw
display as text _n ">>> A2. 默认（normalized）"
xtswitchdid (y x1) (dose), group(id) neffects(6)
display as text _n ">>> A3. estat total"
estat total
restore

display as text _n "--- F8d. 同子样本的 raw 逐期效应 vs 真值 tau ---"
display as text "真值：-0.90 -1.10 -1.30 -1.50 -1.50 -1.50（设计上先增后平）"
preserve
keep if inlist(typ, 0, 3)
xtset id year
xtswitchdid (y x1) (dose), group(id) neffects(6) raw
restore

display as text _n "--- F8e. 归一化分母的第二个检验：dev 恒等于 2 的子样本 ---"
display as text "子样本 typ0(never) + typ5(0→2 @2017)，dev 恒等于 2"
display as text "预测：raw / normalized = 2, 4, 6"
preserve
keep if inlist(typ, 0, 5)
xtset id year
xtswitchdid (y x1) (dose), group(id) neffects(4) raw
display as text _n ">>> B2. 默认（normalized）"
xtswitchdid (y x1) (dose), group(id) neffects(4)
restore
display as text "F8_OK"

*=============================================================================
* 第 9 节  F9 固定 switcher 集（commonswitchers）
*=============================================================================
display as text _n "########## F9 commonswitchers ##########"
display as text _n "--- F9a. 默认：每个暴露期各用各自可用的 switcher，neffects(10) ---"
xtswitchdid (y x1) (dose), group(id) neffects(10)
estat total
display as text _n "--- F9b. commonswitchers：所有暴露期共用同一批，neffects(10) ---"
xtswitchdid (y x1) (dose), group(id) neffects(10) commonswitchers
estat total
display as text "F9_OK"

*=============================================================================
* 第 10 节  F10 隔年采样（delta(2)）
*=============================================================================
display as text _n "########## F10 隔年采样 ##########"
preserve
keep if mod(year, 2) == 0
xtset id year, delta(2)
display as text _n "--- F10a. 隔年样本的年份 ---"
tabulate year
display as text _n "--- F10b. 估计（隔年后暴露期计数减半，neffects(4)）---"
xtswitchdid (y x1) (dose), group(id) neffects(4)
estat total
display as text "F10_OK"
restore

display as text _n "########## 全部完成 ##########"
display as text "DONE_FEATURES_DEMO"
log close
