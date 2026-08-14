* chapter10.do
set more off
use "ops2004.dta", clear
**************************************************
* Increment to R-square
**************************************************
regress env_con educat inc com3 hlthprob epht3, beta
pcorr env_con educat inc com3 hlthprob epht3

**************************************************
* Graphic Displays of normality assumption
**************************************************
histogram env_con, frequency normal kdensity
hangroot env_con, bar
summarize env_con, detail
sktest env_con
regress env_con educat inc com3 hlthprob epht3, beta
predict res, residual
summarize res, detail
sktest res
rvfplot
regress env_con educat inc com3 hlthprob epht3, beta
predict envhat
preserve
set seed 515
sample 100, count
twoway (scatter env_con envhat) (lfit env_con envhat)
restore

**************************************************
* Regression diagnostics
**************************************************
use ops2004.dta, clear
regress env_con educat inc com3 hlthprob epht3, beta
predict yhat
predict residual, residual
predict rstandard, rstandard
list respnum env_con yhat residual rstandard if abs(rstandard) > 2.58 & rstandard < .
dfbeta
list respnum rstandard _dfbeta_1 if abs(_dfbeta_1) > 2/sqrt(3769) & _dfbeta_1 < .
estat vif

**************************************************
* Weighted data
**************************************************
list finalwt finalwt2 in 1/5
regress env_con educat inc com3 hlthprob epht3 [pweight=finalwt], beta

**************************************************
* Dummy variables, Hiearachical/Nested Regression
**************************************************
use nlsy97_selected_variables, clear
recode gender97 (1 = 1 Male) (2 = 0 Female), generate(male)
generate race=race97
replace race=1 if race97==1 & ethnic97==0
replace race=2 if race97==2 & ethnic97==0
replace race=3 if ethnic97==1
replace race=4 if (race97==4 | race97==5) & ethnic97==0
tab2 race race97 ethnic97
recode race (2 = 1 African_American) (1 3/4= 0 Other), generate(aa)
recode race (3 = 1 Hispanic) (1/2 4 = 0 Other), generate(hispanic)
recode race (4 = 1 Other_race ) (1/3 = 0 W_AA_H), generate(other)
tab1 aa hispanic other
regress smday97 age97 male ///
        if !missing(smday97, age97, male, psmoke97, aa, hispanic, other), beta
regress smday97 age97 male psmoke97 ///
        if !missing(smday97, age97, male, psmoke97, aa, hispanic, other), beta
pcorr smday97 age97 male psmoke97 ///
        if !missing(smday97, age97, male, psmoke97, aa, hispanic, other)
regress smday97 age97 male psmoke97 aa hispanic other if !missing(smday97, ///
	age97, male, psmoke97, aa, hispanic, other), beta
test aa hispanic other
nestreg: regress smday97 (age97 male) (psmoke97) (aa hispanic other), beta
regress smday97 age97 male psmoke97 aa hispanic other
regress smday97 age97 male psmoke97 i.race
 
**************************************************
* Interaction
**************************************************
use c10interaction, clear
regress inc educ male, beta
predict incfnoi if male==0
predict incmnoi if male==1
twoway (connected incmnoi educ if male == 1, lcolor(black) lpattern(dot) ///
  msymbol(diamond) msize(large)) (connected incfno educ if male==0, ///
  lcolor(black) lpattern(solid) msymbol(circle) msize(large)), ///
  ytitle(Income in thousands) xtitle(Education) legend(order(1 "Men" 2 "Women")) ///
  scheme(s2manual)
regress inc i.male##c.educ, beta
margins male, at(educ=(8 10 12 14 16 18))
marginsplot

webuse regsmpl, clear
regress ln_wage ttl_exp, beta
twoway lfit ln_wage ttl_exp
binscatter ln_wage ttl_exp
regress ln_wage c.ttl_exp##c.ttl_exp, beta
margins, at(ttl_exp = (0(2)28))
marginsplot
summarize ttl_exp
generate cttl_exp = ttl_exp - 6.215
regress ln_wage c.cttl_exp##c.cttl_exp, beta
margins, at(cttl_exp = (-6(2)22))
marginsplot
twoway (lfit ln_wage ttl_exp) (qfit ln_wage ttl_exp)
generate ttl_sq = ttl_exp*ttl_exp
nestreg: regress ln_wage (ttl_exp) (ttl_sq)
powerreg, r2f(.2) r2r(.0) nvar(3) ntest(3) alpha(.05) power(.90)
powerreg, r2f(.05) r2r(.0) nvar(3) ntest(3) alpha(.05) power(.90)
powerreg, r2f(.45) r2r(.35) nvar(5) ntest(3) alpha(.05) power(.90)
powerreg, r2f(.45) r2r(.35) nvar(3) ntest(1) alpha(.05) power(.90)
powerreg, r2f(.30) r2r(.25) nvar(4) ntest(1) alpha(.05) n(50)

power rsquared 0.26, power(0.90) ntested(5)

power rsquared 0.30 0.40, power(0.9) ntested(2) ncontrol(3)

power rsquared 0.13, n(50) ntested(5)
