* chapter7.do
* Two sample tests and
* how to do randomization
clear
set obs 20
gen id = _n
list
set seed 220
sample 10, count
list
use "gss2002_chapter7.dta", clear
recode prayer (1 = 1 Approve) (2 = 0 Disapprove), gen(schpray)
tabulate schpray prayer, missing
prtest schpray == 0.5

* twosample proportion test
use wide, clear
list
prtest treat == control

use long, clear
list
prtest cure, by(group)

* one smaple t-test for a mean
use gss2002_chapter7, clear
ttest hrs1 == 40 if wrkstat==1

* recode income.do (sample do-file)
* This is a short do-file that recodes income. It does a 
* tabulation to see how income is coded (tab rincom98). People
* given a value of 24 are recoded as missing (mvdecode rincom98,
* mv(24)). We generate a new variable called inc that is equal to the 
* old variable, rincom98. We recode each interval with its
* midpoint. We do a cross-tabulation of the new and old income
* variables as a check.
tabulate rincom98, missing
mvdecode rincom98, mv(24)
generate inc = rincom98
replace inc = 500   if rincom98 == 1
replace inc = 2500  if rincom98 == 2
replace inc = 3500  if rincom98 == 3
replace inc = 4500  if rincom98 == 4
replace inc = 5500  if rincom98 == 5
replace inc = 6500  if rincom98 == 6
replace inc = 7500  if rincom98 == 7
replace inc = 9000  if rincom98 == 8
replace inc = 11250 if rincom98 == 9
replace inc = 13250 if rincom98 == 10
replace inc = 16250 if rincom98 == 11
replace inc = 18750 if rincom98 == 12
replace inc = 21250 if rincom98 == 13
replace inc = 23750 if rincom98 == 14
replace inc = 27500 if rincom98 == 15
replace inc = 32500 if rincom98 == 16
replace inc = 37500 if rincom98 == 17
replace inc = 45000 if rincom98 == 18
replace inc = 55000 if rincom98 == 19
replace inc = 67500 if rincom98 == 20
replace inc = 82500 if rincom98 == 21
replace inc = 100000 if rincom98 == 22
replace inc = 110000 if rincom98 == 23
*tabulate inc rincom98, missing
ttest inc if wrkstat == 1, by(sex)
display "r-squared = " 8.1802^2/(8.1802^2 + 1258)
display "r-squared = " (-4.0)^2/((-4.0)^2 + 100)
esize twosample inc if wrkstat==1, by(sex) cohensd hedgesg pbcorr

esizei 200 50000 25000 250 45000 24000, cohensd hedgesg pbcorr

ttest inc if wrkstat==1 & paeduc<=12 & maeduc<=12, by(sex)
esize twosample inc if wrkstat==1 & paeduc<=12 & maeduc<=12, by(sex)  ///
cohensd hedgesg pbcorr

histogram inc if wrkstat==1 & paeduc<=12 & maeduc<=12, by(sex) normal
esize twosample inc if wrkstat==1, by(sex)
* test for equal variances
sdtest inc if wrkstat == 1, by(sex)

use chores, clear
list

* repeated measures ttest
use gss2002_chapter7, clear
ttest paeduc == maeduc

clear
* power analysis
power twomeans 35 37, sd(10) power(0.90)

* nonparametric alternatives
use nlsy97_chapter7
ranksum psmoke97, by(gender97)
median psmoke97, by(gender97) exact medianties(split)
