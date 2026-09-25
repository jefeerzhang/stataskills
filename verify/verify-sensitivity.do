version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-identification
* chapter:  sensitivity-analysis
* data:     sim:2000x3
* checks:   ovb-identity+partial-r2-identity+evalue-closed-form+psacalc+sensemakr+konfound+evalue-pkg+regsensitivity+rbounds+oster-cross-impl
* ============================
set more off
set seed 20260826

* 必需标记只登记内置证据：可选社区包未装时其标记不出现，不得进入必需清单（ADR-0003）。
display "VERIFY_MARKERS_REQUIRED=OVB_IDENTITY_OK PARTIAL_R2_IDENTITY_OK EVALUE_CLOSED_FORM_OK"

* ---- 1. 遗漏变量偏误公式：同一样本内的精确代数恒等式（内置，无社区包依赖） ----
* 短回归 y x 的系数与长回归 y x z 的系数之差，必须等于 beta_z * (z 对 x 回归的系数)。
* 这是 OLS 的正交代数恒等式，不是近似；psacalc / sensemakr / konfound 都建立在它之上。
clear
set obs 2000
generate double z = rnormal()
generate double x = 0.7 * z + rnormal()
generate double y = 1.0 * x + 0.8 * z + rnormal()

regress y x
scalar b_short = _b[x]

regress y x z
scalar b_long = _b[x]
scalar b_z = _b[z]

regress z x
scalar delta_hat = _b[x]

scalar ovb_actual = b_short - b_long
scalar ovb_predicted = b_z * delta_hat
* 先确认 DGP 确实产生了非平凡偏误，避免恒等式被退化数据平凡满足。
assert abs(ovb_actual) > 0.05
assert abs(ovb_actual - ovb_predicted) < 1e-8
display "OVB_IDENTITY_OK"
display "ovb_bias_actual=" %12.8f ovb_actual
display "ovb_bias_predicted=" %12.8f ovb_predicted

* ---- 2. partial R^2 的两种闭式必须一致（内置） ----
* (a) R^2 增量式：(R2_full - R2_reduced) / (1 - R2_reduced)
* (b) t 统计量式：t^2 / (t^2 + df_residual)
* sensemakr 报的 e(r2yd_x) 就是 (a)/(b) 这个量，第 5 节用它交叉校验。
regress y x z
scalar r2_full = e(r2)
scalar df_full = e(df_r)
regress y z
scalar r2_reduced = e(r2)
scalar partial_r2_from_r2 = (r2_full - r2_reduced) / (1 - r2_reduced)

regress y x z
scalar t_treat = _b[x] / _se[x]
scalar partial_r2_from_t = t_treat^2 / (t_treat^2 + df_full)
assert partial_r2_from_r2 > 0 & partial_r2_from_r2 < 1
assert abs(partial_r2_from_r2 - partial_r2_from_t) < 1e-8
display "PARTIAL_R2_IDENTITY_OK"
display "partial_r2_from_r2=" %12.8f partial_r2_from_r2
display "partial_r2_from_t=" %12.8f partial_r2_from_t

* ---- 3. E-value 闭式：E = RR + sqrt(RR * (RR - 1))（内置） ----
* 两个锚点取自 evalue 官方帮助文件正文给出的数值，用于固定闭式形式。
scalar rr_doc = 3.9
scalar e_doc = rr_doc + sqrt(rr_doc * (rr_doc - 1))
assert abs(e_doc - 7.263) < 0.001

scalar rr_anchor = 1.8
scalar e_anchor = rr_anchor + sqrt(rr_anchor * (rr_anchor - 1))
assert abs(e_anchor - 3.0) < 1e-12
* CI 限同样有闭式：把更靠近 null 的那一侧当作点估计代入同一公式。
scalar rr_lcl = 1.2
scalar e_lcl_expected = rr_lcl + sqrt(rr_lcl * (rr_lcl - 1))

display "EVALUE_CLOSED_FORM_OK"
display "evalue_closed_form_rr3.9=" %12.8f e_doc
display "evalue_closed_form_rr1.8=" %12.8f e_anchor
display "evalue_closed_form_lcl1.2=" %12.8f e_lcl_expected

* ---- 4. 社区包（optional）：已安装时真实估计并断言 stored results ----

* --- 4.1 psacalc：Oster 比例选择 ---
* 实测：rmax() 必须是 (R2_controlled, 1] 区间的**字面量**；
*   rmax(1.3)        → 超过 1，报 "maximum possible R-squared is 1"
*   rmax(1.3*e(r2))  → r(198) option rmax() incorrectly specified（不接受表达式）
*   rmax(<scalar>)   → r(198)（不接受标量名）
* 正确写法是宏展开，让 rmax 在解析前被替换成数字：
cap which psacalc
local has_psacalc = (_rc == 0)
if !`has_psacalc' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__psacalc__"
}
if `has_psacalc' {
    regress y x z
    psacalc delta x, rmax(`=min(1.3 * e(r2), 1)')
    scalar psacalc_delta = r(delta)
    scalar psacalc_rmax = r(rmax)
    * 默认 rmax(1) 的 delta 用于第 4.4 节跨实现校验。
    regress y x z
    psacalc delta x
    scalar psacalc_delta_rmax1 = r(delta)
    regress y x z
    psacalc beta x, rmax(`=min(1.3 * e(r2), 1)') delta(1)
    scalar psacalc_beta = r(beta)
    * r() 缺失时标量是 . ；`< .` 为假，必须硬失败，不能只看命令是否报错。
    assert psacalc_delta < .
    assert psacalc_beta < .
    assert psacalc_rmax > 0 & psacalc_rmax <= 1
    display "psacalc_delta=" %12.8f psacalc_delta
    display "psacalc_rmax=" %12.8f psacalc_rmax
    display "psacalc_delta_rmax1=" %12.8f psacalc_delta_rmax1
    display "psacalc_beta=" %12.8f psacalc_beta
    display "SENSITIVITY_PSACALC_OK"
}

* --- 4.2 sensemakr：Cinelli-Hazlett 稳健值 ---
* 实测：benchmark() 在 benchmark 变量过强时会 r(3498)
* （"Implied bound on r2yz_dx greater than 1, try a lower kd and/or ky"），
* 所以本脚本只用 treat()，不加 benchmark。
cap which sensemakr
local has_sensemakr = (_rc == 0)
if !`has_sensemakr' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__sensemakr__"
}
if `has_sensemakr' {
    sensemakr y x z, treat(x)
    scalar rv_q = e(rv_q)
    scalar rv_qa = e(rv_qa)
    scalar r2yd_x = e(r2yd_x)
    scalar treat_coef = e(treat_coef)
    assert rv_q < . & rv_qa < . & r2yd_x < . & treat_coef < .
    assert rv_q > 0 & rv_q < 1
    * 计入显著性的 RV 必须不大于打到 0 的 RV。
    assert rv_qa <= rv_q
    * 交叉校验：包的 partial R^2 必须等于第 2 节的内置闭式。
    assert abs(r2yd_x - partial_r2_from_r2) < 1e-6
    display "sensemakr_rv_q=" %12.8f rv_q
    display "sensemakr_rv_qa=" %12.8f rv_qa
    display "sensemakr_r2yd_x=" %12.8f r2yd_x
    display "sensemakr_treat_coef=" %12.8f treat_coef
    display "SENSITIVITY_SENSEMAKR_OK"
}

* --- 4.3 konfound：Frank ITCV / RIR（另需 indeplist / matsort / moss） ---
cap which konfound
local has_konfound = (_rc == 0)
cap which indeplist
local has_indeplist = (_rc == 0)
cap which matsort
local has_matsort = (_rc == 0)
cap which moss
local has_moss = (_rc == 0)
if !`has_konfound' | !`has_indeplist' | !`has_matsort' | !`has_moss' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__konfound__"
}
if `has_konfound' & `has_indeplist' & `has_matsort' & `has_moss' {
    * konfound 必须紧接模型，中间不得插入其他命令。
    regress y x z
    konfound x, indx("IT")
    scalar itcv = r(itcv)
    scalar r_xcv = r(r_xcv)
    scalar r_ycv = r(r_ycv)
    assert itcv < . & r_xcv < . & r_ycv < .
    display "konfound_itcv=" %12.8f itcv
    display "konfound_r_xcv=" %12.8f r_xcv
    display "konfound_r_ycv=" %12.8f r_ycv
    regress y x z
    konfound x, indx("RIR")
    scalar rir = r(rir)
    assert rir < . & rir > 0
    display "konfound_rir=" %12.8f rir
    display "SENSITIVITY_KONFOUND_OK"
}

* --- 4.4 regsensitivity：符号翻转 / 归零 breakdown point ---
* 实测：必须有 varlist（depvar indepvar controls）；`regsensitivity, noplot` 报 r(100)。
* 另实测：bounds 子命令存 e(breakdown)，breakdown 子命令的 e(breakdown) 是缺失值，
* 因此只对 bounds 断言。
cap which regsensitivity
local has_regsen = (_rc == 0)
if !`has_regsen' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__regsensitivity__"
}
if `has_regsen' {
    regsensitivity bounds y x z, oster table
    scalar regsen_breakdown = e(breakdown)
    scalar regsen_analysis = e(analysis)
    assert regsen_breakdown < .
    assert regsen_breakdown > 0
    display "regsensitivity_breakdown=" %12.8f regsen_breakdown
    display "regsensitivity_analysis=" "`=regsen_analysis'"
    display "SENSITIVITY_REGSENSITIVITY_OK"
}

* --- 4.5 跨实现校验：两个独立包的 Oster delta 必须一致 ---
* psacalc delta（rmax=1）与 regsensitivity bounds, oster（r2long=1）在同一个 DGP 上
* 给出同一个 Oster delta；实测均为 1.0870182。这是对 A 文档中「两套实现同源」的实测背书。
if `has_psacalc' & `has_regsen' {
    assert abs(psacalc_delta_rmax1 - regsen_breakdown) < 1e-6
    display "oster_cross_impl_delta=" %12.8f psacalc_delta_rmax1
    display "SENSITIVITY_OSTER_CROSS_IMPL_OK"
}

* --- 4.6 evalue：用包复现第 3 节的内置闭式（交叉校验） ---
cap which evalue
local has_evalue = (_rc == 0)
if !`has_evalue' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__evalue__"
}
if `has_evalue' {
    evalue rr 1.8, lcl(1.2) ucl(2.7)
    scalar eval_est = r(eval_est)
    scalar eval_ci = r(eval_ci)
    assert eval_est < . & eval_ci < .
    * 点估计与 CI 限都必须复现内置闭式。
    assert abs(eval_est - e_anchor) < 1e-6
    assert abs(eval_ci - e_lcl_expected) < 1e-6
    display "evalue_pkg_est=" %12.8f eval_est
    display "evalue_pkg_ci=" %12.8f eval_ci
    display "SENSITIVITY_EVALUE_OK"
}

* --- 4.7 rbounds：Rosenbaum bounds，仅 1x1 配对 ---
* 输入是配对内的结果差分；这里手工构造 200 个配对，不依赖 psmatch2。
cap which rbounds
local has_rbounds = (_rc == 0)
if !`has_rbounds' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__rbounds__"
}
if `has_rbounds' {
    preserve
    clear
    set obs 200
    generate double pair = _n
    generate double d = rnormal() + 0.4
    rbounds d, gamma(1 (0.1) 2) sigonly
    scalar rb_rows = rowsof(r(outmat))
    scalar rb_N = r(N)
    scalar rb_alpha = r(alpha)
    assert rb_N == 200
    assert rb_alpha == 0.95
    assert rb_rows == 11
    display "rbounds_N=" %12.0f rb_N
    display "rbounds_rows=" %12.0f rb_rows
    display "SENSITIVITY_RBOUNDS_OK"
    restore
}