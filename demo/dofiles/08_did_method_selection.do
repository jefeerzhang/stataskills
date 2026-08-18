version 19.5
set more off
set seed 20260817

* ============================================================
* DID 方法选择 Demo
*
* 本脚本演示 5 个典型 DID 场景的正确方法选择：
*   场景 1：简单 2x2 DID → xtdidregress
*   场景 2：错时 DID（默认）→ hdidregress aipw
*   场景 3：错时 DID + 计数结果 → jwdid poisson
*   场景 4：错时 DID + leaveout 方差修正 → did_imputation
*   场景 5：少数处理单位 → synth
*
* 每个场景生成模拟数据，运行推荐方法，输出结果。
* ============================================================

* ============================================================
* 场景 1：简单 2x2 DID → xtdidregress
*
* 用户场景：医院政策评估，2020 年 1 月对部分医院实施
* 数据结构：面板（20 家医院 × 36 个月）
* 处理时点：单时点（2020 年 1 月）
* ============================================================
display as text "=== 场景 1：简单 2x2 DID → xtdidregress ==="

clear
set obs 720                      // 20 家医院 × 36 个月
gen hospital_id = ceil(_n/36)
gen month = mod(_n-1, 36) + 1
gen treated = (hospital_id <= 10) // 前 10 家为处理组
gen post = (month >= 13)          // 第 13 个月起为处理后
gen treat_post = treated * post
gen satisfaction = 70 + 5*treated + 3*post + 8*treat_post + rnormal(0, 5)

xtset hospital_id month
xtdidregress (satisfaction) (treat_post), group(hospital_id) time(month)

display as text "场景 1 完成：xtdidregress 报告 ATET = 8（真值）"

* ============================================================
* 场景 2：错时 DID（默认）→ hdidregress aipw
*
* 用户场景：县级就业政策评估，不同县在不同年份实施
* 数据结构：面板（50 个县 × 10 年）
* 处理时点：错时（3 个 cohort：2015, 2017, 2019）
* 对照组：20 个 never-treated 县
* ============================================================
display as text "=== 场景 2：错时 DID → hdidregress aipw ==="

clear
set obs 500                      // 50 个县 × 10 年
gen county = ceil(_n/10)
gen year = mod(_n-1, 10) + 2010
gen first_treat = cond(county <= 10, 2015, cond(county <= 20, 2017, cond(county <= 30, 2019, 0)))
gen treat = (first_treat > 0 & year >= first_treat)
gen employment = 50 + 0.5*year + 2*treat + rnormal(0, 3)

xtset county year
hdidregress aipw (employment) (treat), group(county) time(year)

estat aggregation, overall
estat aggregation, cohort

display as text "场景 2 完成：hdidregress aipw 报告总体 ATT"

* ============================================================
* 场景 3：错时 DID + 计数结果 → jwdid poisson
*
* 用户场景：医院就诊次数评估，不同医院在不同时间接受干预
* 数据结构：面板（40 家医院 × 8 年）
* 结果变量：就诊次数（计数数据）
* ============================================================
display as text "=== 场景 3：错时 DID + 计数结果 → jwdid poisson ==="

* 检查 jwdid 是否安装
capture which jwdid
if _rc != 0 {
    display as text "jwdid 未安装，跳过场景 3"
    display as text "安装命令：ssc install hdfe jwdid, replace"
}
else {
    clear
    set obs 320                    // 40 家医院 × 8 年
    gen hospital = ceil(_n/8)
    gen year = mod(_n-1, 8) + 2015
    gen first_treat = cond(hospital <= 10, 2017, cond(hospital <= 20, 2019, 0))
    gen treat = (first_treat > 0 & year >= first_treat)
    gen visits = rpoisson(5 + 2*treat)

    xtset hospital year
    jwdid visits, ivar(hospital) tvar(year) gvar(first_treat) method(poisson) group
    
    estat simple
    estat event
    
    display as text "场景 3 完成：jwdid poisson 报告 ATT"
}

* ============================================================
* 场景 4：错时 DID + leaveout 方差修正 → did_imputation
*
* 用户场景：面板数据，错时处理，想要最精确的标准误
* 数据结构：面板（40 个单位 × 10 期）
* 用户需求：有限样本方差修正（leaveout）
* ============================================================
display as text "=== 场景 4：错时 DID + leaveout → did_imputation ==="

* 检查 did_imputation 是否安装
capture which did_imputation
if _rc != 0 {
    display as text "did_imputation 未安装，跳过场景 4"
    display as text "安装命令：ssc install reghdfe did_imputation, replace"
}
else {
    clear
    set obs 400                    // 40 个单位 × 10 期
    gen id = ceil(_n/10)
    gen t = mod(_n-1, 10) + 1
    gen first_treat = cond(id <= 10, 3, cond(id <= 20, 7, 0))
    gen treat = (first_treat > 0 & t >= first_treat)
    gen y = 2 + 0.5*t + 1.0*treat + rnormal(0, 1)
    
    * did_imputation 的 Ei 编码：缺失值 = 从未处理（不同于 csdid/jwdid 的 gvar=0）
    gen Ei = first_treat
    replace Ei = . if first_treat == 0
    
    * 基本估计 + leaveout 方差修正
    did_imputation y id t Ei, horizons(0/5) leaveout autosample
    
    * 平行趋势检验
    did_imputation y id t Ei, pretrends(5)
    
    display as text "场景 4 完成：did_imputation leaveout 报告 ATT + 平行趋势检验"
}

* ============================================================
* 场景 5：少数处理单位 → synth
*
* 用户场景：加州控烟政策评估，只有 1 个处理单位
* 数据结构：面板（39 个州 × 31 年）
* 处理单位：只有加州（1 个）
* ============================================================
display as text "=== 场景 5：少数处理单位 → synth ==="

* 检查 synth 是否安装
capture which synth
if _rc != 0 {
    display as text "synth 未安装，跳过场景 5"
    display as text "安装命令：ssc install synth, replace"
}
else {
    * 使用 synth_smoking.dta 数据
    capture use "../synth/synth_smoking.dta", clear
    if _rc != 0 {
        display as text "synth_smoking.dta 不存在，跳过场景 5"
        display as text "下载命令：cd data/synth && bash download_synth_smoking.sh"
    }
    else {
        tsset state year
        
        * 合成控制法
        synth cigsale beer(1984(1)1988) lnincome(1972(1)1988) retprice age15to24 ///
              cigsale(1988) cigsale(1980) cigsale(1975), ///
              trunit(3) trperiod(1989) xperiod(1980(1)1988) nested
        
        display as text "场景 5 完成：synth 报告加州 Prop 99 的合成控制估计"
    }
}

* ============================================================
* 总结
* ============================================================
display as text ""
display as text "=== 方法选择 Demo 总结 ==="
display as text "场景 1：简单 2x2 DID → xtdidregress"
display as text "场景 2：错时 DID → hdidregress aipw"
display as text "场景 3：错时 + 计数结果 → jwdid poisson"
display as text "场景 4：错时 + leaveout → did_imputation"
display as text "场景 5：少数处理单位 → synth"
display as text ""
display as text "详细说明见 demo/SELECTION_DEMO.md"
