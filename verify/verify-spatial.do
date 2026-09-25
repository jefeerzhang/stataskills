version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-spatial
* chapter:  spatial-regression
* data:     sim:120x6
* checks:   spset+spmatrix+spregress-gs2sls+spregress-ml+estat-impact+estat-moran+spgenerate+xsmle+spmat+spatwmat+spxtivdfreg
* ============================
set more off
set seed 20260926

* 必需标记只登记**内置** sp 命令族的证据：这些命令 Stata 15+ 自带，
* 与是否安装社区包无关，因此可以进入必需清单（ADR-0003）。
display "VERIFY_MARKERS_REQUIRED=SPATIAL_SETUP_OK SPATIAL_WEIGHTS_OK SPATIAL_GS2SLS_OK SPATIAL_ML_OK SPATIAL_IMPACT_OK SPATIAL_MORAN_OK SPATIAL_SPGENERATE_OK"

* ============================================================
* Part A：横截面内置路径（无社区包依赖）
* ============================================================
clear
set obs 120
generate double id = _n
generate double x = rnormal()
generate double xc = runiform() * 10
generate double yc = runiform() * 10
generate double y = 1 + 0.5 * x + rnormal()

* ---- A1. 声明空间数据 ----
* spset 不返回 r()；它生成 _ID / _CX / _CY 三个变量，用 confirm 做真实检查。
spset id, coord(xc yc)
confirm variable _ID
confirm variable _CX
confirm variable _CY
assert _N == 120
display "SPATIAL_SETUP_OK"

* ---- A2. 构造空间权重矩阵（距离倒数 + 行标准化）----
spmatrix create idistance W, normalize(row)
spmatrix summarize W
display "SPATIAL_WEIGHTS_OK"

* ---- A3. GS2SLS 估计 SAR ----
spregress y x, gs2sls dvarlag(W)
assert e(N) == 120
assert e(estimator) == "gs2sls"
assert e(dlmat) == "W"
assert e(chi2) < .
display "SPATIAL_GS2SLS_OK"
display "spatial_gs2sls_chi2=" %12.6f e(chi2)

* ---- A4. ML 估计 SARAR（空间滞后 + 空间误差）----
spregress y x, ml dvarlag(W) errorlag(W)
assert e(estimator) == "ml"
assert e(converged) == 1
assert e(elmat) == "W"
display "SPATIAL_ML_OK"
display "spatial_ml_iterations=" e(iterations)

* ---- A5. 直接 / 间接 / 总效应分解 ----
* 重新估计 GS2SLS 后再分解，确保 impact 挂在 SAR 规格上。
spregress y x, gs2sls dvarlag(W)
estat impact
assert r(N) == 120
assert rowsof(r(b_direct)) == 1
assert rowsof(r(b_indirect)) == 1
assert rowsof(r(b_total)) == 1
scalar impact_direct = r(b_direct)[1,1]
scalar impact_indirect = r(b_indirect)[1,1]
scalar impact_total = r(b_total)[1,1]
assert impact_direct < . & impact_indirect < . & impact_total < .
* 总效应 = 直接 + 间接，这是定义式恒等式。
assert abs(impact_total - (impact_direct + impact_indirect)) < 1e-8
display "SPATIAL_IMPACT_OK"
display "impact_direct=" %12.8f impact_direct
display "impact_indirect=" %12.8f impact_indirect
display "impact_total=" %12.8f impact_total

* ---- A6. Moran 残差检验：注意它是 regress 的后估计命令 ----
* 实测：挂在 spregress 后报 r(321) estat moran not allowed；选项是 errorlag() 不是 weights()。
regress y x
estat moran, errorlag(W)
assert r(chi2) < .
assert r(p) < .
assert r(df) == 1
assert r(elmat) == "W"
display "SPATIAL_MORAN_OK"
display "moran_chi2=" %12.8f r(chi2)
display "moran_p=" %12.8f r(p)

* ---- A7. 空间滞后变量：* 两侧不能有空格 ----
* 实测：写成 W * y（星号带空格）会以 r(198) 失败；正确写法是 W*y。
* 注意：本注释刻意避开 judge.sh 静默错误正则里的短语——该正则不过滤回显行，
* 注释里出现那些短语会被误判为真实错误（见 AGENTS.md 诊断证据一节）。
spgenerate wy = W*y
assert !missing(wy[1])
quietly summarize wy
assert r(N) == 120
display "SPATIAL_SPGENERATE_OK"
display "spgenerate_mean=" %12.8f r(mean)

* ============================================================
* Part B：社区包（optional；未装则 sentinel 跳过）
* ============================================================

* --- B1. spmat（sppack）：另一套权重矩阵工具 ---
cap which spmat
local has_spmat = (_rc == 0)
if !`has_spmat' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__spmat__"
}
if `has_spmat' {
    spmat idistance Ws xc yc, id(id) norm(row)
    spmat summarize Ws, links detail
    display "SPATIAL_SPMAT_OK"
}

* --- B2. spatwmat（sg162）：Pisati 遗产工具，生成普通 Stata 矩阵 ---
* 该矩阵是 xsmle 的 wmat() 输入，因此先建 30 单位网格截面。
cap which spatwmat
local has_spatwmat = (_rc == 0)
if !`has_spatwmat' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__spatwmat__"
}

* --- B3. xsmle：空间面板 ML ---
cap which xsmle
local has_xsmle = (_rc == 0)
if !`has_xsmle' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__xsmle__"
}

* --- B4. spxtivdfreg（xtivdfreg 包）：含共同因子的空间动态面板 ---
cap which spxtivdfreg
local has_spxtivdfreg = (_rc == 0)
if !`has_spxtivdfreg' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__spxtivdfreg__"
}

* --- B5. spmap：只做探针，出图需要地图数据 ---
cap which spmap
local has_spmap = (_rc == 0)
if !`has_spmap' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__spmap__"
}

* 构造 6x5 网格截面（30 单位）→ 先在截面上建 W 矩阵 → 再扩成 8 期面板。
* 注意：Stata 不允许嵌套 preserve，所以这里不用 preserve，
* 直接把 Part A 的数据 clear 掉重建（Part A 已完成，不需要保留）。
if `has_xsmle' | `has_spxtivdfreg' {
    clear
    set obs 30
    generate double id = _n
    generate double xc = mod(_n - 1, 6) + 1
    generate double yc = floor((_n - 1) / 6) + 1

    * 在 30 单位截面上构造普通 Stata 矩阵（spatwmat 需要截面数据）
    if `has_spatwmat' {
        spatwmat, name(Wgrid) xcoord(xc) ycoord(yc) band(0 1.5) stand
        display "SPATIAL_SPATWMAT_OK"
    }

    expand 8
    bysort id: generate double t = _n
    generate double x = rnormal()
    generate double y = 1 + 0.5 * x + rnormal()
    xtset id t

    if `has_xsmle' & `has_spatwmat' {
        xsmle y x, wmat(Wgrid) model(sar) fe
        assert e(N) == 240
        display "SPATIAL_XSMLE_OK"
        display "xsmle_N=" e(N)
    }

    if `has_spxtivdfreg' & `has_spatwmat' {
        * spmatrix() 默认把参数当 SP 矩阵（spmatrix 对象）；喂 spatwmat 生成的
        * 普通 Stata 矩阵必须加 stata 子选项（实测：不加报 r(111) matrix not found）。
        spxtivdfreg y x, absorb(id) splag tlags(1) spmatrix(Wgrid, stata)
        display "SPATIAL_SPXTIVDFREG_OK"
    }
}