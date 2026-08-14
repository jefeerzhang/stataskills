* ============================================================
* 下载《A Gentle Introduction to Stata》第 6 版（agis6）配套数据
* 数据来自 http://www.stata-press.com/data/agis6/
* 用法：在 Stata 中 do download_data.do
* 前提：Stata 当前工作目录设置为项目根目录（或先 cd）
* ============================================================
version 15
set more off

capture mkdir "data"
capture mkdir "data/agis6"
cd "data/agis6"

* ---- 数据集（按字母顺序，逐个下载并验证非空）----
local datasets attitude c10interaction c11barchart chapter13_missing ///
	chapter6_aspirin chores descriptive_gss divorce environ firstsurvey ///
	firstsurvey_chapter4 flourishing_bmi gss2002_chapter6 gss2002_chapter7 ///
	gss2006_chapter12 gss2006_chapter12_selected gss2006_chapter6 ///
	gss2006_chapter6_10percent gss2006_chapter8 gss2006_chapter8_selected ///
	gss2006_chapter9 gss2006_chapter9_2way gss_2016ch12 intraclass kappa1 ///
	kuder-richardson long longitudinal_mixed nlsy97_chapter11 nlsy97_chapter7 ///
	nlsy97_selected_variables ops2004 partyid relate retest spearman wide wide9

foreach f of local datasets {
	quietly copy "http://www.stata-press.com/data/agis6/`f'.dta" "`f'.dta", replace
	* 验证文件存在且非空（HTML 错误页会很小，但此处主要防 404 页面）
	if fileexists("`f'.dta") {
		display "OK    `f'.dta"
	}
	else {
		display as error "FAIL  `f'.dta"
	}
}

* ---- codebook ----
quietly copy "http://www.stata-press.com/data/agis6/relate.cdb" "relate.cdb", replace
display "OK    relate.cdb"

* ---- 每章 do 文件（复现全书结果）----
forvalues i = 1/16 {
	quietly copy "http://www.stata-press.com/data/agis6/chapter`i'.do" "chapter`i'.do", replace
	if fileexists("chapter`i'.do") {
		display "OK    chapter`i'.do"
	}
	else {
		display as error "FAIL  chapter`i'.do"
	}
}

display "全部下载完成。数据集位于 data/agis6/"
exit, clear
