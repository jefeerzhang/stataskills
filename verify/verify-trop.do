version 19.5
set more off
* ==== VERIFY CONTRACT ====
* skill:    stata-did-community
* chapter:  trop
* data:     sim:200x10
* checks:   trop-installed+nprobust-installed+factor-estimate
* ============================
* 手动调用：`cd data/agis6 && stata-mp /e do ../../verify/verify-trop.do`
* （Stata for Windows 的 do-file 路径必须从当前目录计算，参考 run-verify.sh）
* trop + nprobust 是 REQUIRED 包（与 csdid / synth / sdid 同级）；本机未装只打 sentinel
* 配套生成 verify-trop.log（raw verify log，按 ADR-0005 保留）

* =============================================================================
* 段 0：包检测（REQUIRED sentinel）
* =============================================================================
display as result "=== 段 0：TROP + nprobust 包检测 ==="

capture which trop
local has_trop = (_rc == 0)
if !`has_trop' {
    display as error "__COMMUNITY_PACKAGE_MISSING__trop__"
    display as error "trop 未安装，请运行 ssc install trop, replace"
}

capture which nprobust
local has_nprobust = (_rc == 0)
if !`has_nprobust' {
    display as error "__COMMUNITY_PACKAGE_MISSING__nprobust__"
    display as error "nprobust 未安装，请运行 ssc install nprobust, replace"
}

if !`has_trop' | !`has_nprobust' {
    display as result "=== 必需包未装，跳过实际跑段（默认模式 PASS）==="
    exit
}

* =============================================================================
* 段 1：TROP 实际跑（两包都装时才执行）
* =============================================================================
display as result ""
display as result "=== 段 1：TROP 因子估计 ==="

clear
set seed 20260831
set obs 200

* 模拟 200 单元 × 10 期面板
gen id = _n
expand 10
sort id
by id: gen t = _n

* 处理：单时点 DID（period 5 起处理，后 100 单元）
gen treat = (id > 100)
gen post  = (t >= 5)
gen D     = treat * post

* 协变量 + 单元 FE + 年 FE + 异质 ATT
gen x1 = rnormal(0, 1)
gen alpha_i = rnormal(0, 1)             // 单元 FE
gen year_eff = 0
bys t: replace year_eff = rnormal(0, 0.3)  // 年 FE
gen ATT_g = 0.3 * (1 + 0.2 * runiform()) // 异质 ATT
gen y = alpha_i + year_eff + x1 + ATT_g * D + rnormal(0, 1)

* TROP 基础估计
trop y, id(id) time(t) treat(D) covariates(x1) factors(k=2)

* 总体 ATT
estat aggregate

* 断言：aggregate 后的 ATT 应在合理范围
* （TROP 估计 ATT 应接近 0.3 SD + 异质 ≈ 0.33 均值）
local att = r(beta)
display as result "  TROP aggregate ATT = " %6.4f `att'
assert inrange(`att', 0.10, 0.60)
display as result "  ✓ TROP ATT 在预期范围 [0.10, 0.60]（异质 ATT 均值 ≈ 0.33）"

* 安慰剂检验
display as result ""
display as result "=== 段 2：estat placebo ==="
estat placebo

display as result ""
display as result "=== 全部测试通过 ==="
