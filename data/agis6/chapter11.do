* chapter11.do
* hypothetical data relating divorce in first 5 years of marriage
* to score on positive feedback in discussions with spouse prior to 
* marriage
use "divorce.dta", clear
list divorce positives
label define yes 1 "Divorced" 0 "Not divorced"
label values divorce yes
scatter divorce positives, scheme(s2mono)
logit divorce positives
predict prdivorce
scatter prdivorce positives, scheme(s2mono)
predict logit, xb
scatter logit positives, scheme(s2mono)
regress divorce positives
predict divols
twoway (scatter divorce positives) (lfit divols positives)

***********************************************
* What is a logit?
***********************************************
use "environ.dta", clear
tab2 environ libcand, row

***********************************************
* Logistic regression examples
***********************************************
use nlsy97_chapter11, clear
summarize drank30 age97 pdrink97 dinner97 male ///
        if !missing(drank30, age97, pdrink97, dinner97, male)
logistic drank30 age97 male pdrink97 dinner97
logit drank30 age97 male pdrink97 dinner97
logit drank30 if !missing(age97, male, pdrink97, dinner97)

display (-1100.0502 - (-1061.0474))/1100.0502 = 0.0355
webuse lbw
logit low smoke, or

use nlsy97_chapter11, clear
logit drank30 age97 male pdrink97 dinner97
listcoef, help
listcoef, help percent

**************************************************
* Create a barchart from listcoef, percent command
**************************************************
use "c11barchart", clear
graph bar (asis) age male peers dinner, bargap(10) ///
	blabel(name, position(outside)) ytitle(Percent Change in Odds) ///
	title(Percentage Change in Odds of Drinking by) ///
	subtitle("Age, Gender, Percent of Peers Drinking, Meals with Family") ///
	legend(off) scheme(s2manual)

**************************************************
* Testing parameter estimates
**************************************************
use nlsy97_chapter11, clear
logistic drank30 male dinner97 pdrink97
estimates store a
logistic drank30 age97 male dinner97 pdrink97
lrtest a
lrdrop1
test pdrink97 dinner97
generate black = race97 - 1
replace black = . if race97 > 2
label define black 0 "White" 1 "Black"
label define drank30 0 "No" 1 "Yes"
label values drank30 drank30
label values black black
logit drank30 age97 i.black pdrink97 dinner97
margins, dydx(black) atmeans

margins black, atmeans
margins, at(pdrink97=(1 2 3 4 5)) atmeans

marginsplot
*modified with graph editor

logit drank30 age97 i.black##c.pdrink97 dinner97

margins black,  at(pdrink97=(1 2 3 4 5)) atmeans
marginsplot

margins black,  at(pdrink97=(1 2 3 4 5)) atmeans

marginsplot

******************************************************
* Nested logistic regression / Hierarchical Regression
******************************************************
nestreg: logistic drank30 (male) (age97) (dinner97 pdrink97)
powerlog, p1(.70) p2(.75) alpha(.05)
powerlog, p1(.70) p2(.75) alpha(.05) rsq(.30) help
