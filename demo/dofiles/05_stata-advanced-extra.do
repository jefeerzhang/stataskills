*==========================================================*
* DEMO 5/5 : stata-advanced（补充）—— 多层模型与 IRT（书第 15–16 章）
* 说明     : 这两个方法需要纵向数据 / 条目数据，auto.dta 不具备该结构，
*            故改用本仓库自带配套数据 skills/data/agis6/。
* 技能源   : skills/stata-advanced/SKILL.md
*==========================================================*
version 19.5
set more off
clear all

*---- 第 15 章：多层（混合）模型 --------------------------
use "../data/agis6/longitudinal_mixed.dta", clear
clonevar drink0 = drink98
clonevar drink2 = drink00
clonevar drink4 = drink02
clonevar drink6 = drink04
clonevar drink8 = drink06
clonevar drink10 = drink08
drop drink98 drink00 drink02 drink04 drink06 drink08
reshape long drink, i(id) j(wave)

* 随机截距线性增长模型
mixed drink c.wave || id:
estimates store linear
margins, at(wave=(0(2)10))
marginsplot, title("Drinking across waves") scheme(s1mono)
graph export "output/05_mixed_margins.png", replace

* 二次增长模型 + LR 比较
mixed drink c.wave##c.wave || id:
estimates store quadratic
lrtest linear quadratic

*---- 第 16 章：项目反应理论（IRT）-----------------------
use "../data/agis6/attitude.dta", clear
irt 1pl dn2 dn4 dn5 dn7 dn10
estat report, byparm sort(b)
estimates store rasch
irt 2pl dn2 dn4 dn5 dn7 dn10
lrtest rasch
irtgraph icc dn4, blocation
graph export "output/05_irt_icc.png", replace
