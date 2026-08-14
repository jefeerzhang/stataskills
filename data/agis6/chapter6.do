* chapter6.do
* gss2002_chapter6.dta
* variables include
*   sex
*   sexfreq
*   marital
**************************************************************
use gss2006_chapter6, clear
tabulate sex abany, row
tabulate sex abany, chi2 expected row
* Type -search chitable- to find and install the -chitable- command
chitable
tabulate sex abany

use chapter6_aspirin
tabulate aspirin heartattack, chi2 row V

use gss2006_chapter6
tabulate health happy, chi2 column gamma row taub V
tabulate sex abany
* interactive tables
tabi 215 269\172 244, chi2 row V

use gss2006_chapter6
table sex, contents(mean hrs1 sd hrs1 count hrs1)
table sex marital, contents(mean hrs1 sd hrs1 freq) row
graph bar (mean) hrs1, over(sex) over(marital) blabel(bar, format(%9.1f)) ///
  title(Hours Worked Last Week) subtitle(By Gender and Marital Status) ///
  scheme(s1mono)

use gss2006_chapter6_10percent
tabulate sex health, lrchi2 row
tab sex health, lrchi2 row
* Type -search chi2power- to find and install the -chi2power- command
chi2power, startf(1) endf(10) incr(1)
