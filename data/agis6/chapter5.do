* chapter5.do
* descriptive_gss.dta
use "descriptive_gss.dta", clear
histogram childs if childs>0, xlabel(1(1)9) discrete frequency ///
   title(Number of Children in Families with at Least One Child) ///
   note(descriptive_gss.dta) scheme(sj)
* tabulate sex and marital with and without plot option
tab1 sex marital polviews
fre sex marital polviews


graph pie, over(marital) cw sort(marital) ///
	title(Marital Status in the United States) note(descriptive_gss.dta) ///
	scheme(s2mono)
histogram marital, discrete percent gap(10) addlabel xlabel(, valuelabel) ///
	title(Marital Status in the United States) scheme(s1mono)
numlabel _all, add
tab1 polviews
summarize polviews, detail
numlabel _all, remove
histogram polviews, discrete percent start(1) ///
   title(Political Views in the United States) subtitle(Adult Population) ///
   note(General Social Survey 2002) xtitle(Political Conservatism) scheme(s1mono)
summarize wwwhr, detail
sktest wwwhr 
histogram wwwhr, frequency
histogram wwwhr if wwwhr < 25, freq by(sex)
by sex, sort: summarize wwwhr
tabstat wwwhr, statistics(mean median sd iqr skewness kurtosis cv) by(sex) ///
  columns(statistics)
graph hbox wwwhr if wwwhr < 25, over(sex) title(Hours Spent on the Internet) ///
  subtitle(By Gender) note(descriptive_gss.dta)
