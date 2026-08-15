version 19.5

* ---- ch12 信度与因子分析 ----
use gss2006_chapter12, clear
recode empathy2 empathy4 empathy5 (1=5)(2=4)(3=3)(4=2)(5=1), pre(rev)
alpha empathy1 revempathy2 empathy3 revempathy4 revempathy5 empathy6 empathy7, asis item min(5)
use kappa1, clear
kap coder1 coder2
use gss2006_chapter12_selected, clear
recode natspac natenvir natheal natcity natcrime natdrug nateduc natrace natarms natfare natroad natsoc natchld natsci (1=3)(2=2)(3=1), prefix(r)
factor rnatspac rnatenvir rnatheal rnatcity rnatcrime rnatdrug rnateduc rnatrace rnatarms rnatfare rnatroad rnatsoc rnatchld rnatsci, pcf
screeplot, yline(1)
rotate

* ---- ch13 sem ----
use flourishing_bmi, clear
sem bmi <- age children incomeln educ quickfood, standardized
estat eqgof
sem bmi <- age children incomeln educ quickfood, method(mlmv) standardized

* ---- ch14 多重插补 ----
use chapter13_missing, clear
misstable summarize ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm
mi set flong
mi register imputed ln_wagem gradem agem ttl_expm tenurem blackm
mi register regular not_smsa south
mi impute mvn ln_wagem gradem agem ttl_expm tenurem blackm, add(5) rseed(2121)
mi estimate, dftable: regress ln_wagem gradem agem ttl_expm tenurem not_smsa south blackm

* ---- ch15 多层模型 ----
use longitudinal_mixed, clear
clonevar drink0 = drink98
clonevar drink2 = drink00
clonevar drink4 = drink02
clonevar drink6 = drink04
clonevar drink8 = drink06
clonevar drink10 = drink08
drop drink98 drink00 drink02 drink04 drink06 drink08
reshape long drink, i(id) j(wave)
mixed drink c.wave || id:
mixed drink c.wave || id: wave, cov(unstructured)
mixed drink c.wave i.male c.wave#i.male || id: wave

* ---- ch16 IRT ----
use attitude, clear
irt 1pl dn2 dn4 dn5 dn7 dn10
estat report, byparm sort(b)
estimates store rasch
predict rasch_score, latent
irt 2pl dn2 dn4 dn5 dn7 dn10
lrtest rasch
irt grm n2 n4 n5 n7 n10
predict confidence, latent
