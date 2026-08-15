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

* ---- 数据集清单（单一来源：data/manifest.txt）----
capture file close _fh
file open _fh using "../manifest.txt", read
local datasets
while r(eof) == 0 {
	file read _fh _line
	local trimmed = trim("`_line'")
	if strpos("`trimmed'", "#") == 1 continue
	if "`trimmed'" == "" continue
	local datasets `datasets' `trimmed'
}
file close _fh
display "从 data/manifest.txt 读取 `: word count `datasets'' 个数据集"

foreach f of local datasets {
	capture erase "`f'.dta"
	quietly copy "http://www.stata-press.com/data/agis6/`f'.dta" "`f'.dta", replace
	* 读文件首行：真实 dta 以 <stata_dta> 开头，404 错误页是 HTML
	local ok 0
	quietly {
		file open _fh using "`f'.dta", read
		file read _fh _line
		file close _fh
	}
	if strpos("`_line'", "<stata_dta>") == 1 {
		local ok 1
	}
	if `ok' {
		display "OK    `f'.dta"
	}
	else {
		display as error "FAIL  `f'.dta"
		capture erase "`f'.dta"
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
