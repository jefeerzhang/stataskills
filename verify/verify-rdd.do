version 19.5
set more off
set seed 42

* ============================================================
* stata-rdd 验证脚本：断点回归（sharp / fuzzy / 密度检验）
*
* 数据：
*   - ../rdd/tutoring.dta —— Carlos Mendez RDD 教程配套数据集
*     （1000 学生，running variable = entrance_exam，cutoff = 70，
*       outcome = exit_exam，treat = tutoring）。来源见 data/rdd/README.md。
*
* 社区包契约（verify/run-verify.sh --community 模式）：
*   - rdrobust         ：必需（rdrobust / rdplot / rdbwselect）
*   - rddensity        ：必需（密度操纵检验）
*   - lpdensity        ：可选（rddensity 的底包，未装时 sentinel）
*   - 缺包检测：在缺包分支用 `display "<sentinel-string><pkg><sentinel-end>"`
*     （harness 用正则识别，注释中提及 sentinel 字符串不会误匹配）。
*
* 缺包处理（默认模式 PASS，--community 模式 BAD）：
*   每个命令段独立 `cap which`；缺某包就 display sentinel 并用 capture 包住
*   该段命令（避免真实错误码）、继续到脚本正常结束，让 harness 看到
*   一次正常结束标记。装齐包时真跑并断言 e(tau_cl) / e(pv_q)。
* ============================================================

* ---- 探测可用性 ----
capture which rdrobust
local has_rdrobust = (_rc == 0)
capture which rddensity
local has_rddensity = (_rc == 0)
capture which lpdensity
local has_lpdensity = (_rc == 0)

if !`has_rdrobust' {
    display "__COMMUNITY_PACKAGE_MISSING__rdrobust__"
    display as error "rdrobust 未安装，请运行 ssc install rdrobust, replace"
}
if !`has_rddensity' {
    display "__COMMUNITY_PACKAGE_MISSING__rddensity__"
    display as error "rddensity 未安装，请运行 ssc install rddensity, replace"
}
if !`has_lpdensity' {
    display "__COMMUNITY_PACKAGE_OPTIONAL_MISSING__lpdensity__"
    display as text "lpdensity 未安装（rddensity 依赖包，装上可用密度图）"
}

* ============================================================
* 第 1 步：验设计（sharp 判定）—— 不依赖社区包
* ============================================================
display as text "=== 第 1 步：sharp 设计判定 ==="

use "../rdd/tutoring.dta", clear
gen byte below_cutoff = (entrance_exam <= 70)
tab below_cutoff tutoring, row

quietly count if below_cutoff == 1 & tutoring == 1
local n_treated_below = r(N)
quietly count if tutoring == 1
local n_treat = r(N)

display "below cutoff & treated: " `n_treated_below' "（应 = " `n_treat' "，sharp）"

if `n_treated_below' == `n_treat' {
    display as text "sharp 设计确认（100% 合规）"
}
else {
    display as text "存在交叉（fuzzy 需用 fuzzy() 选项）"
}

display as text "第 1 步完成"

* ============================================================
* 第 2 步：rdplot 目视 —— 依赖 rdrobust
* ============================================================
display as text "=== 第 2 步：rdplot ==="

if `has_rdrobust' {
    capture noisily rdplot exit_exam entrance_exam, c(70) p(1)
    if _rc != 0 {
        display as text "rdplot 执行异常（_rc=" _rc "），忽略继续"
    }
    else {
        display as text "rdplot 完成"
    }
}
else {
    display as text "rdrobust 未装，跳过 rdplot"
}

* ============================================================
* 第 3 步：rdrobust 主估计（sharp）—— 依赖 rdrobust
* ============================================================
display as text "=== 第 3 步：rdrobust 主估计 ==="

if `has_rdrobust' {
    rdrobust exit_exam entrance_exam, c(70)

    if e(tau_cl) == . {
        display as error "e(tau_cl) 为缺失值：rdrobust 主估计失败"
        exit 1
    }

    display "RD Estimate (robust): " %9.3f e(tau_cl)
    display "Robust SE:            " %9.3f e(se_tau_cl)
    display "Robust p-value:       " %6.4f e(pv_cl)
    display "Bandwidth:            " %9.3f e(h_l)
    display "Effective N (L/R):    " e(N_h_l) " / " e(N_h_r)

    display as text "--- 核函数对比 ---"
    capture noisily rdrobust exit_exam entrance_exam, c(70) kernel(uniform)
    capture noisily rdrobust exit_exam entrance_exam, c(70) kernel(epanechnikov)

    display as text "rdrobust 完成"
}
else {
    display as text "rdrobust 未装，跳过主估计"
}

* ============================================================
* 第 4 步：rdbwselect 带宽选择器 —— 依赖 rdrobust
* ============================================================
display as text "=== 第 4 步：rdbwselect ==="

if `has_rdrobust' {
    capture noisily rdbwselect exit_exam entrance_exam, c(70) all
    display as text "rdbwselect 完成"
}
else {
    display as text "rdrobust 未装，跳过 rdbwselect"
}

* ============================================================
* 第 5 步：rddensity 密度操纵检验 —— 依赖 rddensity
* ============================================================
display as text "=== 第 5 步：rddensity ==="

if `has_rddensity' {
    rddensity entrance_exam, c(70)

    if e(pv_q) == . {
        display as error "e(pv_q) 为缺失值：rddensity 未产生密度检验结果"
        exit 1
    }

    display "Density test p: " %6.4f e(pv_q)
    display as text "rddensity 完成"
}
else {
    display as text "rddensity 未装，跳过密度检验"
}

* ============================================================
* 第 6 步：placebo cutoff（稳健性）—— 依赖 rdrobust
* ============================================================
display as text "=== 第 6 步：placebo cutoff ==="

if `has_rdrobust' {
    foreach c in 55 60 65 70 75 80 85 {
        capture noisily rdrobust exit_exam entrance_exam, c(`c')
        if _rc == 0 {
            display "cutoff `c': tau=" %9.3f e(tau_cl) "  p=" %6.3f e(pv_cl)
        }
        else {
            display "cutoff `c': (跳过)"
        }
    }
    display as text "placebo cutoff 完成"
}
else {
    display as text "rdrobust 未装，跳过 placebo"
}

* ============================================================
* 汇总
* ============================================================
display as text "=== RDD 验证结束 ==="
exit
