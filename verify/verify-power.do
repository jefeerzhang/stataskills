version 19.5
set more off
* ==== VERIFY CONTRACT ====
* skill:    stata-did-community
* chapter:  power-analysis
* data:     sim:200x10
* checks:   bloom-known-value+dgp-invariants+burlig-simulation+consistency
* ============================
* 手动调用：`cd data/agis6 && stata-mp /e do ../../verify/verify-power.do`
* （Stata for Windows 的 do-file 路径必须从当前目录计算，参考 run-verify.sh）
* 是 did-community 的额外方法学工具；run-verify.sh 全量跑 did-community 时经
* targets.sh 委托一并执行（委托清单：verify-synth-sdid verify-power verify-trop）。
* 段 2 依赖 reghdfe：社区包契约里 reghdfe 是 OPTIONAL 级（verify-synth-sdid 的
* did_imputation 依赖）——未装时打 OPTIONAL sentinel 并跳过段 2/3，两模式仍 PASS（ADR-0003）。
* 配套生成 verify-power.log（raw verify log，按 ADR-0005 保留）

* =============================================================================
* 段 1：Bloom 1995 Analytical MDE
* =============================================================================
display as result "=== 段 1：Bloom 1995 Analytical MDE ==="

local N_treated = 100
local N_control = 100
local T_pre = 4
local T_post = 6
local N = `N_treated' + `N_control'
local T = `T_pre' + `T_post'
local sigma_eps = 1.0
local alpha = 0.05
local power_target = 0.80

local z_alpha = invnormal(1 - `alpha'/2)
local z_beta  = invnormal(`power_target')
local var_did = (`sigma_eps'^2) * (1/`N_treated' + 1/`N_control') * ///
    (1/`T_pre' + 1/`T_post')
local mde_sd = (`z_alpha' + `z_beta') * sqrt(`var_did')

* 已知 worked example：两组各 100 个单位、4 pre + 6 post、iid sigma_eps=1。
* Var(DID)=sigma_eps^2*(1/N_treated+1/N_control)*(1/T_pre+1/T_post)，
* 因而双侧 alpha=.05 / power=.80 的 MDE = 0.2557485701。
assert abs(`mde_sd' - 0.2557485701) < 1e-6

display as result "  N = `N' (`N_treated' treated / `N_control' control), " ///
    "T = `T' (`T_pre' pre / `T_post' post), alpha = `alpha', power = `power_target'"
display as result "  Bloom MDE (in SD units) = " %6.4f `mde_sd'

* 断言：worked example 的 MDE 应在 [0.25, 0.26] SD。
assert inrange(`mde_sd', 0.25, 0.26)
display as result "  ✓ Bloom MDE 在预期范围 [0.25, 0.26] SD"

* =============================================================================
* 段 2：面板 Simulation（方法依 Burlig-Preonas-Woerman 2020；单 cohort 简化 DGP）
* =============================================================================
display as result ""
display as result "=== 段 2：面板 Simulation（单 cohort 简化 DGP）==="

* 包探测（ADR-0003）：reghdfe 未装时打 OPTIONAL sentinel 并跳过段 2/3，
* 默认模式与 --community 模式均仍 PASS（段 1 的 Bloom 解析式不依赖任何包）。
capture which reghdfe
local has_reghdfe = (_rc == 0)
if !`has_reghdfe' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__reghdfe__"
    display as error "reghdfe 未安装，请运行 ssc install reghdfe, replace"
    display as result "=== 可选包未装，跳过段 2/3（默认模式 PASS）==="
    exit
}

capture program drop power_dgp
program define power_dgp, rclass
    * 注：用 args 接收位置参数（避免 syntax 解析 ATT/tau 为内置 option）
    * 调用形式：power_dgp N T eff rho
    * DGP 是单 cohort 简化设计（处理组自 period 5 起处理，非原论文的
    * 多 cohort staggered 设计）：验证的是「异质 ATT + 聚类 Monte Carlo
    * 求 power」的方法流程，不宣称复现原论文数值。
    args N T eff rho

    drop _all
    set obs `N'
    gen id = _n
    gen treat = (_n > `N'/2)

    * 单位层随机量必须在 expand 前生成，扩展后才能保持跨期不变。
    gen alpha_i = rnormal(0, 1)
    gen att_draw = runiform()
    summarize att_draw if treat, meanonly
    local att_draw_mean = r(mean)
    gen ATT_g = `eff' * (1 + 0.5 * (att_draw - `att_draw_mean'))
    drop att_draw

    expand `T'
    sort id
    by id: gen t = _n

    gen cohort = cond(treat==1, 5, 0)
    gen post   = (t >= cohort)
    gen D      = treat * post

    * 年固定效应每期只抽一次，同一期所有单位共享。
    bysort t (id): gen year_eff = rnormal(0, 0.3) if _n == 1
    by t: replace year_eff = year_eff[1]

    * 单位内 AR(1) 扰动，rho 是一阶序列相关系数。
    sort id t
    by id: gen eps = rnormal(0, 1) if _n == 1
    by id: replace eps = `rho' * eps[_n-1] + ///
        sqrt(1 - `rho'^2) * rnormal(0, 1) if _n > 1
    egen cluster_id = group(id)

    * DGP 契约：单位 FE / 单位 ATT 跨期恒定，时间 FE 在同一期横截面恒定；
    * 处理组平均 ATT 等于传入的 eff，误差的一阶相关接近 rho。
    bysort id (t): assert alpha_i == alpha_i[1]
    bysort id (t): assert ATT_g == ATT_g[1]
    bysort t (id): assert year_eff == year_eff[1]
    summarize ATT_g if treat, meanonly
    assert abs(r(mean) - `eff') < 1e-8
    sort id t
    by id: gen eps_lag = eps[_n-1] if _n > 1
    correlate eps eps_lag
    assert inrange(r(rho), `rho' - 0.10, `rho' + 0.10)
    drop eps_lag

    * 结局 = 单元 FE + 年 FE + 异质 ATT * D + 扰动
    gen y = alpha_i + year_eff + ATT_g * D + eps

    * TWFE 估计
    reghdfe y D, absorb(id t) cluster(cluster_id)
    return scalar beta = _b[D]
    return scalar se   = _se[D]
end

* 在 ATT=0.3 SD 下跑 power（500 reps）
* （注：0.3 SD 略高于 iid 均匀效应解析 MDE 0.2557；simulation 另含
* 单位异质 ATT 与 AR(1) 扰动，因此以 Monte Carlo 直接估计实际 power。）
simulate beta = r(beta) se = r(se), ///
    reps(500) seed(20260831): power_dgp 200 10 0.3 0.5

summarize beta
summarize se
gen t_stat = beta / se
gen rejected = (abs(t_stat) > invnormal(0.975))
summarize rejected
local power_at_03 = r(mean)
display as result "  Power at ATT=0.3 SD (N=200, T=10, rho=0.5) = " %5.3f `power_at_03'

* 断言：ATT=0.3 SD 下 power 应在 [0.5, 0.95] 范围
* （异质 ATT + 500 reps 下应检测出 0.3 SD 效应；过 0.95 说明 power 过高，过 0.5 说明 simulation 异常）
assert inrange(`power_at_03', 0.5, 0.95)
display as result "  ✓ Power at ATT=0.3 SD 在预期范围 [0.5, 0.95]"

* =============================================================================
* 段 3：一致性断言 — Bloom MDE 与 simulation ATT 阈值
* =============================================================================
display as result ""
display as result "=== 段 3：一致性断言 ==="

* Bloom MDE 是在均匀效应假设下达到 80% power 的最小效应；
* simulation 用异质 ATT + AR(1) 扰动，ATT=0.3 应能检测（power > 0.5）
* 一致性断言：Bloom 给的 MDE（均匀效应）应 < simulation 用的 ATT（异质 ATT）
* Bloom MDE ≈ 0.256 SD < 0.3 SD，断言成立
assert (`mde_sd' < 0.30)
display as result "  ✓ Bloom MDE (" %6.4f `mde_sd' ") < ATT=0.3 SD（Burlig simulation ATT 阈值）"

display as result ""
display as result "=== 全部测试通过 ==="
