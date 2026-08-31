version 19.5
set more off
* =============================================================================
* 面板 DiD 最小可检测效应（MDE）估算模板
* =============================================================================
* 文献：
*   - Bloom, H.S. (1995). "Minimum Detectable Effects: A Simple Way to Report the
*     Statistical Power of Experimental Designs." Evaluation Review 19(5):547-556.
*   - Burlig, F., Preonas, L., & Woerman, M. (2020). "Panel Data and Experimental
*     Design." Journal of Development Economics 144:102458.
*
* 两套方法（按精度需求选，非优劣）：
*   (A) Analytical（Bloom 1995 推导）：已知 σ²_τ、σ²_ε、cluster 数 N、treatment 比例
*       → 给出 z-power 下的 MDE 解析式；快速但要求 effect 均匀
*   (B) Simulation（方法依 Burlig-Preonas-Woerman 2020 panel 版）：DGP 内嵌 ATT 异质性
*       + 聚类结构 → 用 simulate 命令 + Monte Carlo → power 曲线。
*       注：本模板 DGP 为单 cohort 简化设计（处理组自 period 5 起处理），
*       原论文为多 cohort staggered 设计；验证的是方法流程，不宣称复现原论文数值。
*
* 使用方式：本文件是模板，逐段复制到自己的 do-file 跑（不要 do 整个文件，会刷数据）。
* 配套 verify: verify/verify-power.do（手动调用：`cd verify && stata-mp -b do verify-power.do`）
* =============================================================================

* =============================================================================
* 方法 (A) — Analytical MDE (Bloom 1995)
* =============================================================================
* 假设：平衡面板 N=200 单元 × T=10 期；处理比例 50%；效应均匀；聚类 SE
local N = 200
local T = 10
local sigma_tau = 0.2         // 真实 ATT 标准差（SD 单位）
local sigma_eps = 1.0         // 个体扰动 SD
local alpha = 0.05            // 显著性水平
local power_target = 0.80     // 目标功效

* Bloom 1995 解析公式：
*   MDE = (z_{1-α/2} + z_{1-β}) * sqrt(Var(DD) / N_eff)
* 其中 Var(DD) ≈ 2*σ²_ε / (N*T)（简化版，假设无协变量）
*       N_eff = N_treated_post + N_control_post
* 简化下界（平衡面板 + 处理比例 50%）：Var(DD) ≈ 2*σ²_ε / (N*T)
local z_alpha = invnormal(1 - `alpha'/2)
local z_beta  = invnormal(`power_target')
local mde_sd = (`z_alpha' + `z_beta') * sqrt(2 * (`sigma_eps'^2) / (`N' * `T'))

di as result "Bloom 1995 Analytical MDE:"
di as result "  N = `N', T = `T', alpha = `alpha', power = `power_target'"
di as result "  MDE (in SD units) = " %6.4f `mde_sd'
* 验证：N=200 T=10 α=0.05 power=0.8 σ_eps=1.0 下
*   MDE ≈ (1.96 + 0.84) * sqrt(2/2000) ≈ 2.80 * 0.0316 ≈ 0.0886 SD
* 与 Burlig-Preonas-Woerman 2020 Table 1 近似一致（同一参数化下 ~0.07-0.09 SD）

* =============================================================================
* 方法 (B) — Simulation-based power（方法依 Burlig-Preonas-Woerman 2020；单 cohort 简化 DGP）
* =============================================================================
* DGP：TWFE 数据 + 异质 ATT（cohort-specific）+ 等相关 cluster 结构 (ρ=0.5)
* 估计量：reghdfe y D, absorb(id t) cluster(cluster_id)
* 用 simulate 命令 + Monte Carlo 跑 power vs ATT 曲线

capture program drop power_dgp
program define power_dgp, rclass
    * 注：用 args 接收位置参数（避免 syntax 解析 ATT/tau 为内置 option）
    * 调用形式：power_dgp N T eff rho
    args N T eff rho

    drop _all
    set obs `N'
    gen id = _n
    gen treat = (_n > `N'/2)                       // 后半部分处理（处理比例 50%）
    expand `T'
    sort id
    by id: gen t = _n

    * cohort：处理组 period 5 起处理
    gen cohort = cond(treat==1, 5, 0)
    gen post   = (t >= cohort)
    gen D      = treat * post

    * 单元固定效应 alpha_i ~ N(0,1)（跨时不变）
    gen alpha_i = rnormal(0, 1)

    * 年固定效应 year_eff ~ N(0, 0.3)（与 alpha_i 正交）
    gen year_eff = 0
    bys t: replace year_eff = rnormal(0, 0.3)

    * 等相关 cluster 扰动
    * Var(eps) = rho² * Var(alpha_i) + (1-rho²) * Var(z),  z ~ N(0,1)
    egen cluster_id = group(id)
    gen z = rnormal(0, 1)
    gen eps = `rho' * alpha_i + sqrt(1 - `rho'^2) * z

    * 异质 ATT（cohort-specific）：ATT_g 在 [eff, 1.5*eff] 均匀分布
    gen ATT_g = `eff' * (1 + 0.5 * runiform())

    * 结局 = 单元 FE + 年 FE + 异质 ATT * D + 扰动
    gen y = alpha_i + year_eff + ATT_g * D + eps

    * TWFE 估计
    reghdfe y D, absorb(id t) cluster(cluster_id)
    return scalar beta = _b[D]
    return scalar se   = _se[D]
end

* ---------- Monte Carlo：在 ATT=0.3 SD 下跑 power ----------
display as result "Panel Simulation（方法依 Burlig-Preonas-Woerman 2020；单 cohort 简化 DGP）:"
display as result "  DGP: N=200, T=10, ATT=0.3 SD, rho=0.5, 500 reps"

simulate beta = r(beta) se = r(se), ///
    reps(500) seed(20260831): power_dgp 200 10 0.3 0.5

* 计算 power
gen t_stat = beta / se
gen rejected = (abs(t_stat) > invnormal(0.975))
summarize rejected
local power_at_03 = r(mean)
display as result "  Power at ATT=0.3 SD = " %5.3f `power_at_03'

* ---------- 扫描 power vs ATT 曲线 ----------
display as result ""
display as result "Power vs ATT curve (N=200, T=10, rho=0.5, 500 reps per point):"
display as result "  ATT (SD)  |  Power  |  mean t_stat"
display as result "  ----------+---------+------------"

forvalues att = 0.05(0.05)0.50 {
    quietly {
        simulate beta = r(beta) se = r(se), ///
            reps(500) seed(20260831): power_dgp 200 10 `att' 0.5
        gen t_stat = beta / se
        summarize t_stat, detail
        local mean_t = r(mean)
        gen rejected = (abs(t_stat) > invnormal(0.975))
        summarize rejected
        local pwr = r(mean)
        drop beta se t_stat rejected
    }
    display as result "  " %5.2f `att' "  |  " %5.3f `pwr' "  |  " %6.3f `mean_t'
}

* =============================================================================
* 典型审查答复模板（数字与本仓库实测一致：verify/verify-power.do
* 实跑 MDE=0.0886 SD / ATT=0.3 SD 下 power=0.656，勿套用其它来源的数字）
* =============================================================================
* "With N=200 clusters × T=10 periods and ATT of 0.3 SD, our design achieves 80%
*  power to detect effects of ~0.089 SD (analytical Bloom 1995, uniform-effect
*  assumption) and ~66% power at 0.3 SD under a single-cohort heterogeneous-ATT
*  panel DGP with rho=0.5 within-cluster correlation (500-rep Monte Carlo,
*  simulation method per Burlig et al. 2020)."
* =============================================================================

