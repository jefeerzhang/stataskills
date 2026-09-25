version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-regression
* chapter:  ch10.11
* data:     sim:40x6
* checks:   xtabond+xtdpdsys+dynamic-panel-diagnostics
* =========================

display "VERIFY_MARKERS_REQUIRED=DYNAMIC_PANEL_AR_TEST_OK DYNAMIC_PANEL_OVERID_TEST_OK DYNAMIC_PANEL_INSTRUMENT_COUNT_OK"
clear
set seed 20260910
set obs 40
gen id = _n
expand 6
bysort id: gen t = _n
xtset id t
gen u = rnormal()
gen x = rnormal()
gen y = .
sort id t
by id: replace y = u if t == 1
by id: replace y = 0.55 * y[_n-1] + 0.35 * x + u if t > 1

* 内置 Difference GMM：AR(1)/AR(2) 与过度识别证据
xtabond y x, lags(1) twostep vce(robust)
estat abond
* 只 display 标记不足以证明检验算出来了：e(arm1)/e(arm2) 缺失时必须硬失败。
assert e(arm1) < . & e(arm2) < .
display "DYNAMIC_PANEL_AR_TEST_OK"
* Sargan 需要非 robust VCE；robust 规格的有效性判断由 Hansen 承担。
* 实测：vce(robust) 下 estat sargan 只打印 "cannot calculate"、_rc 仍为 0、
* e(sargan) 留成缺失值 —— 所以必须断言，不能靠 return code 或标记。
xtabond y x, lags(1) twostep
estat sargan
assert e(sargan) < .
display "DYNAMIC_PANEL_OVERID_TEST_OK"
assert e(zrank) > 0 & e(N_g) > 0
display "DYNAMIC_PANEL_INSTRUMENT_COUNT=" e(zrank) "/" e(N_g)
display "DYNAMIC_PANEL_INSTRUMENT_COUNT_OK"

* 内置 System GMM：作为独立敏感性规格运行
xtdpdsys y x, lags(1) twostep vce(robust)
estat abond
assert e(arm1) < . & e(arm2) < .

* 内置细粒度矩条件控制（dynamic-panel.md 第 2 节示例语法）
xtdpd y L.y x, dgmmiv(y, lagrange(2 4)) iv(x) twostep vce(robust)
estat abond
assert e(arm2) < .

* 社区包：已安装时验证额外诊断；未安装时保持 optional sentinel。
* sentinel 必须写成块形式：单行 `if !.. display ".."` 的日志回显以 `. if` 开头，
* judge 的回显过滤（^[.].*display）虽已覆盖，但仓库其余 30+ 处均为块形式。
cap which xtabond2
local has_xtabond2 = (_rc == 0)
if !`has_xtabond2' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__xtabond2__"
}
if `has_xtabond2' {
    xtabond2 y L.y x, gmmstyle(L.y, laglimits(2 3) collapse) ///
        ivstyle(x) twostep robust small
    display "xtabond2_instruments=" e(j)
    display "xtabond2_groups=" e(N_g)
    display "xtabond2_hansen_p=" e(hansenp)
    matrix list e(diffsargan)
    assert e(j) > 0
    assert e(N_g) > e(j)
    display "DYNAMIC_PANEL_XTABOND2_DIAGNOSTICS_OK"
}

cap which xtdpdgmm
local has_xtdpdgmm = (_rc == 0)
if !`has_xtdpdgmm' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__xtdpdgmm__"
}
if `has_xtdpdgmm' {
    xtdpdgmm y L.y x, model(diff) gmmiv(L.y, lag(2 3) collapse) ///
        iv(x) twostep vce(robust)
    estat abond
    estat overid
    assert e(arm2) < .
    display "DYNAMIC_PANEL_XTDPDGMM_DIAGNOSTICS_OK"
}
