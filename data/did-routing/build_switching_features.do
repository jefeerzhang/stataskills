*=============================================================================
* build_switching_features.do
* 生成 data/did-routing/switching_features.dta
* 用途：REPORT-10 讲稿的数据底座 —— 多值、可切换（非吸收）处理的模拟面板
*
* 设计目标：让 xtswitchdid 的 10 个功能开关每一个都在数据里有真实来源
*   F1 基线 / F2 初始处理非零 / F3 仅升档 / F4 仅降档 / F5 仅 never 对照
*   F6 路径特定 / F7 省内比较 / F8 原始 vs 归一化 / F9 固定 switcher 集
*   F10 隔年采样（delta(2)）
*
* 记录：seed 20260929；280 县 × 16 年 = 4480 观测；2020 年结局缺失
*=============================================================================
version 19.5
clear all
set more off
set seed 20260929

local outdir "C:/Users/jefeer/Downloads/stataskills/data/did-routing"
capture log close _all
log using "`outdir'/build_switching_features.log", replace text

*-----------------------------------------------------------------------------
* 1. 面板骨架：280 个县 × 16 年（2010-2025）
*-----------------------------------------------------------------------------
set obs 4480
gen long id = ceil(_n/16)                 // 县编号 1..280
bysort id: gen int year = 2009 + _n       // 2010..2025
gen byte province = ceil(id/10)           // 28 个省，每省 10 个县（超组）
gen byte typ = mod(id, 8)                 // 8 类路径，每类 35 个县

*-----------------------------------------------------------------------------
* 2. 处理路径 dose ∈ {0,1,2}
*    骨干：never 组占 3 类；切换组占 5 类，分早批（2012）与晚批（2017），
*          且升档与降档成对出现，另有 1 类非吸收往返路径
*-----------------------------------------------------------------------------
gen byte dose = 0

* --- never switchers：全程不动，覆盖三个初始水平 ---
replace dose = 1 if typ == 1              // 初始 1，永远 1
replace dose = 2 if typ == 2              // 初始 2，永远 2
* typ == 0 恒定 0（默认值）

* --- 早批（2012 首次切换，暴露期最长）---
replace dose = 1 if typ == 3 & year >= 2012            // 初始 0 → 1   升档 +1
replace dose = 1 if typ == 4 & year <= 2011            // 初始 1
replace dose = 2 if typ == 4 & year >= 2012            //         1 → 2   升档 +1
replace dose = 2 if typ == 7                           // 初始 2
replace dose = 1 if typ == 7 & year >= 2012            //         2 → 1   降档 -1
replace dose = 0 if typ == 7 & year >= 2018            //         1 → 0   再降 -1（非吸收）

* --- 晚批（2017 首次切换，暴露期短，制造 switcher 构成随暴露期变化）---
replace dose = 2 if typ == 5 & year >= 2017            // 初始 0 → 2   升档 +2
replace dose = 2 if typ == 6 & year <= 2016            // 初始 2
replace dose = 1 if typ == 6 & year >= 2017            //         2 → 1   降档 -1

*-----------------------------------------------------------------------------
* 3. 路径元信息：初始水平 d0、首次切换年 f、暴露期 ell
*-----------------------------------------------------------------------------
gen byte d0 = dose if year == 2010
bysort id: replace d0 = d0[1]

gen int f = 0
replace f = 2012 if inlist(typ, 3, 4, 7)
replace f = 2017 if inlist(typ, 5, 6)

* 三个初始水平都要有 switcher，否则 xtswitchdid 会把整个初始水平丢掉
*   初始 0：never=typ0 | 升档 typ3(+1) typ5(+2)
*   初始 1：never=typ1 | 升档 typ4(+1)
*   初始 2：never=typ2 | 降档 typ6(-1) typ7(-1,-1)

gen int ell = 0
replace ell = year - f + 1 if f > 0 & year >= f        // 暴露 1 期＝切换当年

gen double dev = dose - d0                             // 相对初始水平的当期偏离

*-----------------------------------------------------------------------------
* 4. 真值参数：处理效应函数
*    tau = -dev * (rate + ramp * min(ell,4))
*    · rate 升档 > 降档  → switchgroup(in) 与 (out) 的效应不对称（棘轮效应）
*    · 早批 rate 大、晚批 rate 小 → 队列异质，commonswitchers 才有内容
*    · ramp 随暴露期累积、4 期封顶 → 事件研究曲线单调放大后走平
*-----------------------------------------------------------------------------
gen double rate = 0
replace rate = 0.70 if inlist(typ, 3, 4)      // 早批升档
replace rate = 0.55 if typ == 5               // 晚批升档
replace rate = 0.45 if typ == 7               // 早批降档（下降的好处小于上升的代价）
replace rate = 0.30 if typ == 6               // 晚批降档

gen double ramp = 0
replace ramp = 0.20 if f == 2012
replace ramp = 0.12 if f == 2017

gen double tau = -dev * (rate + ramp * min(ell, 4))

*-----------------------------------------------------------------------------
* 5. 不可观测成分
*-----------------------------------------------------------------------------
gen double u = rnormal(0, 0.5) if year == 2010         // 县固定冲击
bysort id: replace u = u[1]

sort province id year
by province: gen byte _firstp = (_n == 1)
gen double theta = rnormal(0, 0.04) if _firstp == 1     // 省特有线趋势
by province: replace theta = theta[1]
drop _firstp
sort id year

gen double x1 = rnormal()                              // 县-年 时变协变量
gen double e  = rnormal(0, 1)                          // 幂等噪声

*-----------------------------------------------------------------------------
* 6. 结局
*    y = 10 + 0.15*province + u + [0.12 + theta]*(year-2010) + 0.2*x1 + tau + e
*    · 0.12 为全国共同年度趋势（DID 差分掉，不构成识别问题）
*    · theta 为省特有线趋势（跨省比较会串味 → supergroup(province) 的用武之地）
*-----------------------------------------------------------------------------
gen double y = 10 + 0.15*province + u + (0.12 + theta)*(year - 2010) ///
             + 0.2*x1 + tau + e

replace y  = . if year == 2020                          // 结局故意缺失一年
replace x1 = . if year == 2020

*-----------------------------------------------------------------------------
* 7. 真值表：交付前自检 + 讲稿引用
*-----------------------------------------------------------------------------
display as text _n "===== 每个县一条：typ / d0 / f ====="
preserve
bysort id: keep if _n == 1
tabulate typ, summarize(d0)
tabulate typ, summarize(f)
restore

display as text _n "===== 每个 typ 的真值参数 ====="
tabulate typ, summarize(rate)
tabulate typ, summarize(ramp)
display as text _n "===== dose 路径快照（列＝年份）====="
table (typ) (year) if inlist(year,2010,2011,2013,2018,2023), statistic(mean dose) nformat(%3.1f) nototals

display as text _n "===== 真值 tau 按 typ × 暴露期 ell ====="
table (ell) (typ) if ell > 0, statistic(mean tau) nformat(%5.2f) nototals

display as text _n "===== 真值 tau 按 typ（相对初始水平的当期偏离 dev）====="
table (typ) (dev), statistic(mean tau) nformat(%5.2f) nototals

display as text _n "===== 单元数检查 ====="
count
count if y == .
count if year == 2020

label var id       "县 id"
label var year     "年份"
label var province "省（supergroup）"
label var typ      "路径类型 0-7"
label var dose     "离散处理 0/1/2"
label var x1       "时变协变量"
label var y        "结局（2020 年缺失）"
label var tau      "真值处理效应"
label var d0       "初始处理水平"
label var f        "首次切换年（0＝从不切换）"

keep id year province typ dose x1 y tau d0 f rate ramp
order id year province typ dose x1 y tau d0 f rate ramp

compress
save "`outdir'/switching_features.dta", replace
display as text _n "DONE_BUILD_SWITCHING_FEATURES"
log close
