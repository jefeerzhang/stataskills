set scheme s2mono

/* code for figure 15.1 - doesn't go to users */

clear
input y x1 x2 x3 x4 x5
0  2  0  4  0  2
2  3  1  5  0  4
4  4  2  6  0  6
6  5  3  7  0  8
8  6  4  8  0  10
10 7  5  9  0  12
end

twoway connected x1 y, msymbol(circle) mcolor(black) ///
  xtitle(Wave) ytitle(Number of Drinks Last 30 Days) ///
  title(Fixed Part of Random-Effects Model) name(A, replace) legend(off)
twoway connected x1 y, msymbol(circle) mcolor(black) || ///
  connected x2 y, msymbol(circle) mcolor(black) || ///
  connected x3 y, msymbol(circle) mcolor(black) ///
  xtitle(Wave) ytitle(Number of Drinks Last 30 Days) ///
  title(Random Intercepts) name(B, replace) legend(off)
twoway connected x3 y, msymbol(circle) mcolor(black) || ///
  connected x4 y, msymbol(circle) mcolor(black) || ///
  connected x5 y, msymbol(circle) mcolor(black) ///
  xtitle(Wave) ytitle(Number of Drinks Last 30 Days) ///
  title(Random Coefficients) name(C, replace) legend(off)
graph combine A B C

/* end figure 15.1 - commands below go in the do-file for readers*/

use "longitudinal_mixed.dta", clear
/*
 age of all people was 17 in 1997. We analyze # days they drank
in the last 30 days for 1998, 2000, 2002, 2004, 2006, and 2008
*/


clonevar drink0 = drink98
clonevar drink2 = drink00
clonevar drink4 = drink02
clonevar drink6 = drink04
clonevar drink8 = drink06
clonevar drink10 = drink08
drop drink98 drink00 drink02 drink04 drink06 drink08

reshape long drink, i(id) j(wave)

twoway connected drink wave if id < 100, connect(L)

* Random Intercept Linear Trend
mixed drink c.wave || id:
estimates store linear
margins, at(wave=(0(2)10))
marginsplot

* Random Intercept Quadratic Trend
mixed drink c.wave##c.wave || id:
estimates store quadratic
margins, at(wave=(0(2)10))
marginsplot
lrtest linear quadratic

* Treating time as categorical
mixed drink i.wave || id:
estimates store means
margins, at(wave=(0(2)10))
marginsplot
lrtest linear means
lrtest quadratic means

* Random coefficients
mixed drink c.wave || id: wave, cov(unstructured)
predict yhat_drink, fitted
twoway (lfit yhat_drink wave, lwidth(thick))				///
		(line yhat_drink wave if id == 13)	///
		(line yhat_drink wave if id == 61)	///
		(line yhat_drink wave if id == 77)	///
		(line yhat_drink wave if id == 82)	///	
		(line yhat_drink wave if id == 54)	///
		(line yhat_drink wave if id == 125)	///
	   (line yhat_drink wave if id == 134)	///	
	   (line yhat_drink wave if id == 138)	///
	   (line yhat_drink wave if id == 334)	///
	   (line yhat_drink wave if id == 364)	///
	   (line yhat_drink wave if id == 559)	///
	   (line yhat_drink wave if id == 715)	///
	   (line yhat_drink wave if id == 938), legend(off)

* Random coefficients model with time invariant covariate
* gender coded as male = 1, female = 0
mixed drink c.wave i.male || id: wave
margins male, at(wave=(0(2)8))
marginsplot

* Random coefficients, with wave interacting with the
* time invariant covariate--gender coded
mixed drink c.wave##i.male || id: wave
margins male, at(wave=(0(2)8))
marginsplot

mixed drink c.wave##c.wave##i.male || id: wave
margins male, at(wave=(0(2)8))
marginsplot

