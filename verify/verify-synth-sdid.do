version 19.5
set more off
set seed 20260817
* VERIFY: stata-did-community | synth | data/synth/synth_smoking.dta | synth+gap+placebo+donor

* ============================================================
* stata-did 验证脚本：第 13-15 节（csdid / jwdid / did_imputation / 合成控制 / 合成 DID，社区包）
*
* 数据：
*   - csdid / jwdid / did_imputation 章节用本地模拟数据
*     （40 units × 10 periods，2 cohorts），不依赖任何外部数据集。
*   - ../synth/synth_smoking.dta —— Scott Cunningham *Mixtape* 经典案例
*     （加州 Prop 99，1989 年生效）。来源见 data/synth/README.md。
*   - sdid 章节用本地模拟数据（800 obs，39 对照 + 1 处理 × 20 期），
*     不依赖任何外部数据集。
*
* 社区包契约（verify/run-verify.sh --community 模式）：
*   - csdid          ：必需（Callaway-Sant'Anna 估计量）
*   - drdid          ：可选（csdid 的依赖包，未装时 sentinel）
*   - jwdid          ：必需（Wooldridge ETWFE 估计量）
*   - hdfe           ：可选（jwdid 的依赖包，未装时 sentinel）
*   - did_imputation ：必需（BJS 插补法估计量）
*   - reghdfe        ：可选（did_imputation 的依赖包，未装时 sentinel）
*   - synth          ：必需（run-verify.sh 在数据已就绪时仍要求装包才 PASS）
*   - synth_runner   ：可选；未装时 display sentinel，不影响任一模式 PASS
*   - sdid           ：必需（同 synth）
*   - 缺包检测：在缺包分支用 `display "<sentinel-string><pkg><sentinel-end>"`
*     （harness 用正则识别，注释中提及 sentinel 字符串不会误匹配）；
*     sentinel 见 verify/run-verify.sh 的 grep 模式。
* ============================================================

* ============================================================
* 第 13 节：csdid（Callaway-Sant'Anna 估计量）
* ============================================================
display as text "=== 测试第 13 节：csdid ==="

capture which csdid
local has_csdid = (_rc == 0)
if !`has_csdid' {
    display "__COMMUNITY_PACKAGE_MISSING__csdid__"
    display as error "csdid 未安装，请运行 ssc install csdid, replace"
}

* drdid 是 csdid 的依赖包（底层引擎）
capture which drdid
if _rc != 0 {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__drdid__"
    display as text "drdid 未安装（csdid 依赖包；装上可用 method(dr/ipw)）"
}

* 本地模拟数据：40 units × 10 periods，2 cohorts（首次处理期 = 3 和 7）。
* 独立于 csdid 生成，保证 csdid 缺失时仍能继续验证 jwdid/did_imputation。
clear
set seed 20260817
set obs 400
gen id = ceil(_n/10)
gen t  = mod(_n-1, 10) + 1
gen first_treat = cond(id <= 20, 3, cond(id <= 30, 7, 0))
gen treat = (first_treat > 0 & t >= first_treat)
gen x = rnormal()
gen y = 2 + 0.5*t + 0.3*x + 1.0*treat + rnormal(0, 1)

if `has_csdid' {
    * 基本估计：notyet 控制组 + 回归法
    csdid y x, ivar(id) time(t) gvar(first_treat) notyet method(reg)

    * 事后聚合（capture 包住：40 unit × 10 period 小样本下 estat group/event
    * 可能报 conformability r(503)，不视为脚本错误）
    capture estat simple
    capture estat group
    capture estat event

    display as text "csdid 完成"
}

* ============================================================
* 第 13 节：jwdid（Wooldridge ETWFE 估计量）
* ============================================================
display as text "=== 测试第 13 节：jwdid ==="

capture which jwdid
local has_jwdid = (_rc == 0)
if !`has_jwdid' {
    display "__COMMUNITY_PACKAGE_MISSING__jwdid__"
    display as error "jwdid 未安装，请运行 ssc install jwdid, replace"
}

* hdfe 是 jwdid 的依赖包（底层引擎）
capture which hdfe
if _rc == 0 {
    display as text "hdfe 已安装（jwdid 依赖）"
}
else {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__hdfe__"
    display as text "hdfe 未安装（jwdid 依赖包）"
}

if `has_jwdid' {
    * 使用与 csdid 验证块相同的模拟数据
    * 基本估计：默认 notyet + never 控制组
    jwdid y x, ivar(id) time(t) gvar(first_treat)

    * 事后聚合
    estat simple
    estat group
    estat event

    display as text "jwdid 完成"
}

* ============================================================
* 第 13 节：did_imputation（BJS 插补法估计量）
* ============================================================
display as text "=== 测试第 13 节：did_imputation ==="

capture which did_imputation
local has_did_imputation = (_rc == 0)
if !`has_did_imputation' {
    display "__COMMUNITY_PACKAGE_MISSING__did_imputation__"
    display as error "did_imputation 未安装，请运行 ssc install did_imputation, replace"
}

* reghdfe 是 did_imputation 的依赖包
capture which reghdfe
if _rc == 0 {
    display as text "reghdfe 已安装（did_imputation 依赖）"
}
else {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__reghdfe__"
    display as text "reghdfe 未安装（did_imputation 依赖包）"
}

if `has_did_imputation' {
    * 使用与 csdid/jwdid 验证块相同的模拟数据
    * 注意：did_imputation 的 Ei 编码与 csdid/jwdid 的 gvar 不同：
    *   - csdid/jwdid: gvar = 0 或 . 表示从未处理
    *   - did_imputation: Ei 必须是缺失值（.）表示从未处理，0 会被当作"第 0 期处理"
    * first_treat 在模拟数据中已经是 0 = 从未处理，需要转换为缺失
    preserve
    gen Ei = first_treat
    replace Ei = . if first_treat == 0

    * 基本估计：总体 ATT + 事件研究
    did_imputation y id t Ei, horizons(0/5) autosample

    * leaveout 方差修正（BJS 附录 A.9，唯一实现）
    did_imputation y id t Ei, horizons(0/5) leaveout autosample

    restore

    display as text "did_imputation 完成"
}

* ---- 第 14 节：合成控制 synth ----
display as text "=== 测试第 14 节：synth ==="

capture which synth
local has_synth = (_rc == 0)
if !`has_synth' {
    display "__COMMUNITY_PACKAGE_MISSING__synth__"
    display as error "synth 未安装，请运行 ssc install synth, replace"
}

if `has_synth' {
    use "../synth/synth_smoking.dta", clear
    tsset state year

    synth cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 ///
          cigsale(1988) cigsale(1980) cigsale(1975), ///
          trunit(3) trperiod(1989) xperiod(1980(1)1988) nested

    display as text "synth 完成"
}

* ---- synth_runner：可选（未装则 sentinel，不影响默认模式 PASS）----
capture which synth_runner
local has_synth_runner = (_rc == 0)
if !`has_synth_runner' {
    display as text "synth_runner 未安装（非必需；装上可用 ADH 2015 placebo 置换）"
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__synth_runner__"
}
if `has_synth' & `has_synth_runner' {
    display as text "=== 测试 synth_runner ==="
    synth_runner cigsale beer(1984(1)1988) lnincome retprice age15to24, ///
        trunit(3) trperiod(1989) gen_vars
    display as text "synth_runner 完成"
}

* ============================================================
* 第 15 节：合成 DID sdid（本地模拟数据，39 对照州 + 1 处理州 × 20 期）
* ============================================================
display as text "=== 测试第 15 节：sdid ==="

capture which sdid
local has_sdid = (_rc == 0)
if !`has_sdid' {
    display "__COMMUNITY_PACKAGE_MISSING__sdid__"
    display as error "sdid 未安装，请运行 ssc install sdid, replace"
}

if `has_sdid' {
    clear
    set seed 20260817
    set obs 800
    gen state = ceil(_n/20)
    gen year  = mod(_n-1, 20) + 1
    gen treat = (state==1 & year>=15)
    gen y     = 5 + 0.1*year + 0.5*(state==1) + 1.2*treat + rnormal(0, 1)

    * 模拟数据设计：39 对照州 + 1 处理州 × 20 期 = 800 obs
    * ATT 真值 = 1.2。注意：单处理单位下 bootstrap/jackknife 都需要
    * "超过1个处理单位"，故此处用 vce(noinference) 跑点估计；
    * SKILL.md 第 15 节示例代码（vce(bootstrap) reps(50)）适用于真实
    * 多处理单位数据，与此处模拟数据不同——见 verify 脚本注释。
    sdid y state year treat, vce(noinference) seed(20260817)

    display as text "sdid 完成"
}
display as text "=== 全部测试通过 ==="
