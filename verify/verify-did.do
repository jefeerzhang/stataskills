version 19.5
* VERIFY: stata-did | did | sim:24000x5 | didregress+atet+paralleltrend

* ============================================================
* stata-did 验证脚本
* 覆盖 SKILL.md 核心可执行路径：didregress（重复截面 DID/DDD、
* Donald–Lang 聚合、wild bootstrap）/ xtdidregress（面板 DID）/
* hdidregress + xthdidregress（异质性 DID、错时处理 cohort）/
* estat trendplot / ptrends / granger / bdecomp / atetplot /
* aggregation 事后诊断。数据全部本地模拟（set seed 固定），不依赖网络与
* 额外 .dta。所有图形命令在批处理模式下静默执行，不导出文件。
* ============================================================
set more off
set seed 20260816

* ---- 1. 重复截面 DID：didregress（flyer 医院满意度例的结构）----
clear
set obs 24000                          // 2 组 × 12 期 × 1000 人
gen month    = ceil(_n/2000)           // 1–12
gen hospital = mod(_n, 2)              // 0/1 两组医院
gen treat    = (hospital==1 & month>=7)
gen satis    = 50 + 3*hospital + 0.5*month + 2*treat + rnormal(0, 3)

didregress (satis) (treat), group(hospital) time(month)
estat trendplot                        // 平行趋势图（事后）

* ---- 2. 三重差分 DDD：group() 放两个组变量 ----
* 政策只作用于（处理医院 × 参保患者），处理在两维度组合上变化
gen insured = (runiform() < 0.5)       // 第三维度：是否参保
gen post    = (month >= 7)
gen treat3  = (hospital==1 & post & insured==1)
* 重建结局：医院级政策效应 1.0 + 参保者额外效应 1.5
gen satis3 = 50 + 3*hospital + 0.5*month + 1*insured ///
             + 1.0*(hospital==1 & post) + 1.5*treat3 + rnormal(0, 3)

didregress (satis3) (treat3), group(hospital insured) time(month)

* ---- 3. Donald–Lang 聚合：aggregate(dlang) ----
didregress (satis) (treat), group(hospital) time(month) aggregate(dlang)

* ---- 4. Wild bootstrap 推断：wildbootstrap ----
didregress (satis) (treat), group(hospital) time(month) ///
    wildbootstrap(reps(99) rseed(20260816))

* ---- 5. 面板 DID：xtdidregress ----
clear
set obs 6000                           // 500 个体 × 12 期
gen id    = ceil(_n/12)
gen month = mod(_n-1, 12) + 1
xtset id month
gen grp   = mod(id, 2)
gen treat = (grp==1 & month>=7)
gen x1    = rnormal()
gen satis = 50 + 3*grp + 0.5*month + 2*treat + 0.8*x1 + rnormal(0, 3)

xtdidregress (satis x1) (treat), group(grp) time(month)
estat trendplot                        // 平行趋势图
estat ptrends                          // 事前平行趋势检验
estat granger                          // Granger 型事前趋势检验

* ---- 6. 异质性 DID：hdidregress twfe（错时处理 cohort，SKILL.md 第 5 节）----
clear
set obs 7200                           // 600 个体 × 12 期
gen id     = ceil(_n/12)
gen month  = mod(_n-1, 12) + 1
xtset id month
gen cohort = mod(id, 3)                // 0=从未处理，1=第5期起，2=第8期起
gen treat  = (cohort==1 & month>=5) | (cohort==2 & month>=8)
gen u      = rnormal(0, 1) if month==1
bysort id: replace u = u[1]
gen y      = 10 + month*0.3 + u + ///
             (cohort==1)*(month>=5)*(1 + 0.2*(month-5)) + ///
             (cohort==2)*(month>=8)*(1.5 + 0.1*(month-8)) + rnormal(0, 1)

hdidregress twfe (y) (treat), group(id) time(month)
estat atetplot                         // 各 cohort 的 ATET 图
estat aggregation                      // 总体聚合（默认 overall）
estat aggregation, cohort              // 按 cohort 聚合
estat aggregation, dynamic             // 按处理暴露期聚合（事件研究）

* ---- 7. 回归调整估计量：hdidregress ra（SKILL.md 第 5 节）----
hdidregress ra (y) (treat), group(id) time(month)
estat aggregation, overall

* ---- 8. 异质性 DID 面板版：xthdidregress（沿用第 6 节数据，SKILL.md 第 6 节）----
xtset id month
xthdidregress twfe (y) (treat), group(id)
estat atetplot
estat aggregation, cohort

* ---- 9. 效应分解：bdecomp（需错时处理 + 强平衡，重造错时数据，SKILL.md 第 7 节）----
clear
set obs 4800                           // 4 组医院 × 12 期 × 100 人
gen month    = ceil(_n/400)
gen hospital = mod(_n-1, 4)            // 0/1 对照，2 第5期处理，3 第8期处理
gen treat    = (hospital==2 & month>=5) | (hospital==3 & month>=8)
gen satis2   = 50 + 3*hospital + 0.5*month + 2*treat + rnormal(0, 3)
* bdecomp 要求强平衡：收缩到组×期均值（每格一观测）
collapse (mean) satis2 treat, by(hospital month)

didregress (satis2) (treat), group(hospital) time(month)
estat bdecomp                          // 处理效应分解（DID/ATT/选择项）
