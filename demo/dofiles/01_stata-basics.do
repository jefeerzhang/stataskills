*==========================================================*
* DEMO 1/6 : stata-basics —— 数据管理与清洗（书第 1–4 章）
* 技能源   : stata-basics/SKILL.md
* 数据     : auto.dta（Stata 自带 1978 Automobile Data, N=74）
* 运行     : stata-mp -b do dofiles/01_stata-basics.do
*==========================================================*
version 19.5
set more off
clear all

*---- 第 1 章：起步，读入数据、查看结构 --------------------
sysuse auto, clear
describe
codebook, compact

*---- 第 2 章：检查数据与缺失值 ---------------------------
misstable summarize
summarize
tabulate rep78, miss

*---- 第 3 章：数据准备（本 skill 重点）--------------------
* 3.1 生成新变量（计量单位换算 / 标记变量）
generate price_k = price / 1000
generate wt_tons = weight / 2000
generate high_mpg = (mpg >= 25)
label variable price_k "Price (thousands USD)"
label variable wt_tons "Weight (tons)"
label variable high_mpg "MPG >= 25"

* 3.2 值标签（两步：先 define 再 values）
*    说明：auto.dta 的 foreign 已自带 origin 标签(0=Domestic 1=Foreign)，
*    无需重定义；这里给新建变量 high_mpg 打标签作示范。
label define highlab 0 "No" 1 "Yes"
label values high_mpg highlab

* 3.3 字符串变量编码成数值（encode）
encode make, gen(make_id)
label variable make_id "Make (encoded)"

* 3.4 查看值标签定义
labelbook origin highlab

* 3.5 egen 分组汇总
egen mean_price_all = mean(price)
bysort foreign: egen mean_price_by_origin = mean(price)

* 3.6 压缩存储
compress

*---- 第 4 章：do-file 结果管理 —— 保存清洗后的数据 --------
save "data/auto_clean.dta", replace

*---- 清洗结果核对 ----------------------------------------
describe
codebook foreign high_mpg rep78, compact
summarize price price_k weight wt_tons mpg
tabulate foreign high_mpg
list make price price_k mpg foreign high_mpg in 1/10, noobs
