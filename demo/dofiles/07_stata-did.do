*==========================================================*
* DEMO 7/7 : stata-did —— 双重差分 DID 命令族示例
* 技能源   : stata-did/SKILL.md
* 数据     : 本地模拟（flyer 案例复刻），不依赖外部 .dta
* 参考     : Stata 19 DID flyer (https://www.stata.com/flyers/did19.pdf)
* 运行     : stata-mp -b do dofiles/07_stata-did.do
*==========================================================*
version 19.5
set more off
clear all
set seed 20260816

* ============================================================
* Part A：重复截面 DID / DDD / Donald-Lang / Wild bootstrap
*   数据复刻 flyer 第 1 节：医院满意度（monthly data,
*   before/after new procedure）。对照组+处理组, 12 个月,
*   month>=7 为政策后。
* ============================================================

*---- A1：构造数据（flyer hospital 案例） --------------------
clear
set obs 24000                          // 2 组医院 × 12 期 × 1000 病人
gen month    = ceil(_n/2000)           // 1–12
gen hospital = mod(_n, 2)              // 0 对照 / 1 处理
gen treat    = (hospital==1 & month>=7)
gen satis    = 50 + 3*hospital + 0.5*month + 2*treat + rnormal(0, 3)

label variable satis    "Patient satisfaction"
label variable hospital "Hospital group (0=control, 1=treated)"
label variable treat    "Treated post-period indicator"
label variable month    "Calendar month"

*---- A2：基础 DID（didregress） + 平行趋势图 --------------
didregress (satis) (treat), group(hospital) time(month)
estat trendplot, ///
    title("Parallel-trends diagnostic (flyer hospital case)") ///
    note("Outcome: patient satisfaction; treat policy onset at month 7") ///
    scheme(s1mono)
graph export "output/07_trendplot_did.png", replace

*---- A3：DDD（三重差分）------------------------------------
* flyer 第 1 节"group() 放两个组变量"：政策只对
* 处理医院 × 参保患者组合生效。
gen insured = (runiform() < 0.5)       // 第三维度：是否参保
gen post    = (month >= 7)
gen treat3  = (hospital==1 & post & insured==1)
gen satis3  = 50 + 3*hospital + 0.5*month + 1*insured ///
              + 1.0*(hospital==1 & post) + 1.5*treat3 + rnormal(0, 3)

didregress (satis3) (treat3), group(hospital insured) time(month)

*---- A4：Donald-Lang 聚合（aggregate(dlang)） -------------
* flyer 第 2 节：组数少时更稳的推断。
didregress (satis) (treat), group(hospital) time(month) aggregate(dlang)

*---- A5：Wild cluster bootstrap 推断 ----------------------
* flyer 第 2 节：reps() 控制重抽次数，rseed() 控制种子。
didregress (satis) (treat), group(hospital) time(month) ///
    wildbootstrap(reps(99) rseed(20260816))

* ============================================================
* Part B：面板 DID —— xtdidregress
*   flyer 第 1 节"if our data were panel"路径。本 demo 用本地
*   模拟的平衡面板（500 个体 × 12 期）演示；现实中也可用
*   Stata 自带 mus03subps 等面板数据替换数据源。
* ============================================================

*---- B1：构造平衡面板（flyer 案例的 panel 版）-----------
clear
set obs 6000                           // 500 个体 × 12 期
gen id     = ceil(_n/12)
gen month  = mod(_n-1, 12) + 1
xtset id month
gen grp    = mod(id, 2)
gen treat  = (grp==1 & month>=7)
gen x1     = rnormal()
gen satis  = 50 + 3*grp + 0.5*month + 2*treat + 0.8*x1 + rnormal(0, 3)

label variable grp   "Group (0=control, 1=treated)"
label variable treat "Treated post-period indicator"

*---- B2：面板 DID + 平行趋势检验 --------------------------
xtdidregress (satis x1) (treat), group(grp) time(month)
estat trendplot, ///
    title("Parallel-trends diagnostic (xtdidregress)") ///
    scheme(s1mono)
graph export "output/07_xtdidregress_trendplot.png", replace

estat ptrends                          // 事前平行趋势检验
estat granger                          // Granger 型事前趋势检验
estat grangerplot, ///
    title("Granger causality plot") ///
    scheme(s1mono)
graph export "output/07_xtdidregress_granger.png", replace

* ============================================================
* Part C：异质性 DID（错时处理 cohort）
*   flyer 第 3 节：hdidregress / xthdidregress 提供
*   异质性稳健估计量（避免 TWFE 在错时下的负权重偏误）。
* ============================================================

*---- C1：构造错时处理数据 -------------------------------
clear
set obs 7200                           // 600 个体 × 12 期
gen id     = ceil(_n/12)
gen month  = mod(_n-1, 12) + 1
xtset id month
* 三个 cohort：cohort=0 从未处理；cohort=1 第5期起；
* cohort=2 第8期起。
gen cohort = mod(id, 3)
gen treat  = (cohort==1 & month>=5) | (cohort==2 & month>=8)
* 异质性 ATET：cohort 1 的效应随时间线性增长，
* cohort 2 起点更高但增速更慢。
gen u      = rnormal() if month==1
bysort id (month): replace u = u[1]
gen y      = 10 + month*0.3 + u + ///
              (cohort==1)*(month>=5)*(1 + 0.2*(month-5)) + ///
              (cohort==2)*(month>=8)*(1.5 + 0.1*(month-8)) + ///
              rnormal(0, 1)

label variable y      "Outcome (heterogeneous treatment effects)"
label variable cohort "Treatment cohort (0=never, 1=early, 2=late)"
label variable treat  "Treated post-period indicator"

*---- C2：hdidregress twfe + 各 cohort ATET 图 ------------
hdidregress twfe (y) (treat), group(id) time(month)
estat atetplot, ///
    title("ATET by cohort (hdidregress twfe)") ///
    note("Heterogeneous treatment effects across treatment cohorts") ///
    scheme(s1mono)
graph export "output/07_hdidregress_atetplot.png", replace

*---- C3：聚合（overall / cohort / dynamic 事件研究） -------
estat aggregation
estat aggregation, cohort graph
graph export "output/07_hdidregress_agg_cohort.png", replace

estat aggregation, dynamic graph
graph export "output/07_hdidregress_agg_dynamic.png", replace

*---- C4：hdidregress ra（回归调整估计量） -----------------
hdidregress ra (y) (treat), group(id) time(month)
estat aggregation, overall

*---- C5：xthdidregress（面板版异质性 DID）----------------
xtset id month
xthdidregress twfe (y) (treat), group(id)
estat atetplot, ///
    title("ATET by cohort (xthdidregress)") ///
    scheme(s1mono)
graph export "output/07_xthdidregress_atetplot.png", replace
estat aggregation, cohort

* ============================================================
* Part D：Bacon 分解（错时设计的 TWFE 偏误来源诊断）
*   SKILL.md 第 7 节两条前提：(1) 处理时点 ≥2；
*   (2) 数据强平衡 → 先 collapse 到组×期均值再估计。
* ============================================================

clear
set obs 4800                           // 4 组医院 × 12 期 × 100 人
gen month    = ceil(_n/400)
gen hospital = mod(_n-1, 4)            // 0/1 对照，2 第5期处理，3 第8期处理
gen treat    = (hospital==2 & month>=5) | (hospital==3 & month>=8)
gen satis2   = 50 + 3*hospital + 0.5*month + 2*treat + rnormal(0, 3)

* 强平衡化：收缩到组×期均值（每格一观测）
collapse (mean) satis2 treat, by(hospital month)

label variable satis2   "Mean satisfaction by hospital-month"
label variable hospital "Hospital group (staggered treatment)"
label variable treat    "Treated post-period indicator"
label variable month    "Calendar month"

didregress (satis2) (treat), group(hospital) time(month)
estat bdecomp                          // 处理效应分解
estat bdecomp, graph ///
    title("Bacon decomposition (TWFE weights)") ///
    scheme(s1mono)
graph export "output/07_bdecomp.png", replace

* ============================================================
* Part E：汇总演示中各命令与图
* ============================================================
display "==================================================="
display " stata-did demo summary"
display "---------------------------------------------------"
display " Part A: repeated-cross-section DID/DDD/DLang/wild"
display "   - didregress + trendplot       -> 07_trendplot_did.png"
display "   - didregress DDD               -> text output"
display "   - didregress aggregate(dlang)  -> text output"
display "   - didregress wildbootstrap     -> text output"
display " Part B: panel DID"
display "   - xtdidregress + trendplot     -> 07_xtdidregress_trendplot.png"
display "   - estat ptrends / granger      -> text output"
display "   - estat grangerplot            -> 07_xtdidregress_granger.png"
display " Part C: heterogeneous DID (staggered)"
display "   - hdidregress twfe + atetplot  -> 07_hdidregress_atetplot.png"
display "   - estat aggregation, cohort    -> 07_hdidregress_agg_cohort.png"
display "   - estat aggregation, dynamic   -> 07_hdidregress_agg_dynamic.png"
display "   - hdidregress ra + aggregation -> text output"
display "   - xthdidregress + atetplot     -> 07_xthdidregress_atetplot.png"
display " Part D: Bacon decomposition"
display "   - estat bdecomp, graph         -> 07_bdecomp.png"
display "==================================================="