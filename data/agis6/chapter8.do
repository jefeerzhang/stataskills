* chapter8.do
* Chapter 8: Correlation and Regression
use gss2006_chapter8, clear
****************************************************
* SCATTERGRAMS	
****************************************************
set seed 111
sample 100, count
twoway (scatter educ paeduc) if sex==1, ytitle(Son's education) ///
  yscale(titlegap(5)) xtitle(Father's education) ///
  title(Scattergram relating father's education to his son's education, ///
  size(medium)) note(Data source: GSS 2006; random subsample of N = 100) legend(off)
twoway (scatter educ paeduc, jitter(6) jitterseed(222)) if sex==1, ///
  ytitle(Son's education) yscale(titlegap(5)) xtitle(Father's education) ///
  title(Scattergram relating father's education to his son's education, ///
  size(medium)) note(Data source: GSS 2006; random subsample of N = 100) legend(off)
twoway (scatter educ paeduc, jitter(6) jitterseed(222)) (lfit educ paeduc) ///
  if sex==1, ytitle(Son's education) yscale(titlegap(5)) ///
  xtitle(Father's education) ///
  title(Scattergram relating father's education to his son's education, ///
  size(medium)) ///
  note(Data source: GSS 2006; random sample of N = 100) legend(off)

sysuse nlsw88, clear
keep if age > 34 & age < 45 & race < 3
scatter wage tenure
binscatter wage tenure
binscatter wage tenure, rd(3.0)
binscatter wage tenure, rd(3.0) by(race)

****************************************************
* CASEWISE AND PAIRWISE CORRELATION
****************************************************
use https://stats.idre.ucla.edu/stat/data/hsb2, clear
correlate read write math science ses female
pwcorr read write math science socst ses female, listwise sig star(5)
pwcorr read write math science socst ses female, sig obs star(5)
pwcorr read write math science socst ses female, bon sig obs star(5)

****************************************************
* REGRESSION AND CURVE FITTING
****************************************************
use gss2006_chapter8_selected, clear
summarize prestg80 hrs1
regress prestg80 hrs1, beta
regress prestg80 hrs1
twoway (lfitci prestg80 hrs1), scheme(s2mono)

****************************************************
* Spearman's rho
****************************************************
use spearman, clear
list 
power onecorrelation 0 0.20
