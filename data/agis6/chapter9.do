* chapter9.do
***************************************
* ONEWAY ANOVA
***************************************
use partyid, clear
oneway stemcell partyid, bonferroni tabulate
pwmean stemcell, over(partyid) effects cimeans mcompare(bonferroni)

use gss2006_chapter9, clear
oneway prestg80 mobile16 if age > 29 & age < 60 & wrkstat==1, bonferroni ///
  tabulate


graph bar (mean) prestg80 if age > 29 & age < 60 & wrkstat==1, over(mobile16) ///
  scheme(s2mono)
power oneway, ngroups(3) delta(.1(.05).4)
power oneway, ngroups(3) delta(.1(.05).4) power(.7(.1).9) alpha(.05 .01)

**************************************
* NONPARAMETRIC ALTERNATIVE
**************************************
use partyid, clear 
kwallis stemcell, by(partyid)
tabstat stemcell, statistics(mean median sd) by(partyid)
graph hbar (median) stemcell, over(partyid) ///
  title(Median stem cell attitude score by party identification) ///
  ytitle(Median score on stem cell attitude) ///
  scheme(s2mono)
graph box stemcell, over(partyid) ///
   scheme(s2mono)

********************************************
* Analysis of Covariance
********************************************
use gss2006_chapter9, replace
tabulate mobile16 if age > 29 & age < 60 & wrkstat==1, summarize(prestg80)
tabulate age if age > 29 & age < 60 & wrkstat==1, summarize(prestg80)
anova prestg80 mobile16 age if age > 29 & age < 60 & wrkstat==1
anova prestg80 mobile16 c.age if age > 29 & age < 60 & wrkstat==1
margins mobile16, atmeans
tab mobile16 sex if age > 29 & age < 60 & wrkstat==1, col chi2
anova prestg80 mobile16 sex c.age if age > 29 & age < 60 & wrkstat==1
margins mobile16#sex, atmeans
estat esize
estat esize, omega

estat esize, epsilon

*****************
* TWO-WAY ANOVA 
******************
use gss2006_chapter9_2way, clear
tabulate married, summarize(tvhours)
tabulate workfull, summarize(tvhours)
anova tvhours workfull married
tabulate workfull married, summarize(tvhours)
anova tvhours workfull married workfull#married
margins workfull married workfull#married
quietly: margins workfull
marginsplot
quietly: margins married
marginsplot, noci
quietly: margins workfull#married
marginsplot, noci

******************************************
* REPEATED MEASURES 
******************************************
use wide9, clear
list
reshape long test, i(id) j(time)
list
xtset id
xtreg test
anova test id time, repeated(time)
margins time

*******************************************
* INTRACLASS CORRELATION
*******************************************
use intraclass, clear
list
xtset group
xtreg medicare
power oneway, n(40(20)500) power(0.80) alpha(0.05) ngroups(3) graph table
power twoway, nrows(2) ncols(3) power(0.80) n(100(20)300) factor(column) ///
  graph table
power repeated, n(100(10)300) power(0.80) alpha(0.05) corr(0.60) nrepeated(4) ///
  ngroups(1) graph table
