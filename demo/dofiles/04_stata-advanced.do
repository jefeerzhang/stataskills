*==========================================================*
* DEMO 4/5 : stata-advanced —— 进阶测量与现代方法（书第 12–14 章）
* 技能源   : stata-advanced/SKILL.md
* 数据     : auto.dta
*==========================================================*
version 19.5
set more off
clear all
sysuse auto, clear

*---- 第 12 章：因子分析（PCF 主成分因子）-----------------
factor price mpg weight length displacement gear_ratio, pcf
screeplot, title("Scree Plot") scheme(s1mono)
graph export "output/04_screeplot.png", replace
rotate
* 仅 1 个因子被保留（特征值>1），预测因子得分 f1
predict f1
list make f1 in 1/10, noobs

*---- 第 13 章：SEM / GSEM --------------------------------
* sem 等价于线性回归（可画路径图、可用 FIML 处理缺失）
regress price mpg weight length
sem price <- mpg weight length, standardized
estat eqgof

* gsem 做 logistic
logit foreign mpg weight price
gsem foreign <- mpg weight price, family(binomial) link(logit)
estat eform

*---- 第 14 章：多重插补（rep78 有缺失）-------------------
misstable summarize rep78 price mpg weight length
drop make
mi set mlong
mi register imputed rep78
mi register regular price mpg headroom trunk weight length turn displacement gear_ratio foreign
mi impute mvn rep78 = price mpg weight length, add(20) rseed(12345)
mi estimate: regress price rep78 mpg weight length foreign
