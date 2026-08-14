* chapter12.do
* How do I create a scale
use gss2006_chapter12, clear
* ***************************************************
* Constructing a Scale & Alpha
* ***************************************************
recode empathy2 empathy4 empathy5 (1=5 "Does not describe very well") ///
  (2=4) (3=3) (4=2) (5=1 "Describes very well"), pre(rev) label(empathy)
egen empathy = rowmean(empathy1 revempathy2 empathy3 revempathy4 ///
  revempathy5 empathy6 empathy7)
egen miss = rowmiss(empathy1 revempathy2 empathy3 revempathy4 ///
   revempathy5 empathy6 empathy7) 
egen empathya = rowmean(empathy1 revempathy2 empathy3 revempathy4 ///
   revempathy5 empathy6 empathy7) if miss < 3
alpha empathy1 revempathy2 empathy3 revempathy4 revempathy5 /// 
  empathy6 empathy7, asis item min(5)

* ***************************************************
* Test retest correlation
*****************************************************
use "retest.dta", clear
pwcorr score1 score2, obs sig

use gss2006_chapter12, clear
recode empathy2 empathy4 empathy5 (1=5 "Does not describe very well") ///
  (2=4) (3=3) (4=2) (5=1 "Describes very well"), pre(rev) label(empathy)
alpha empathy1 revempathy2 empathy3 revempathy4 revempathy5 empathy6 empathy7, ///
	asis item min(5)

*****************************************************
* KR20
*****************************************************
clear
use "kuder-richardson.dta"
alpha newartmus1 newartmus2 newartview newartinfo newartmus3, asis item

*****************************************************
* Kappa
*****************************************************
clear
use "kappa1.dta"
tabulate coder1 coder2
kap coder1 coder2

use gss_2016ch12, clear
alpha hope1-hope6, asis item label generate(hope)

generate work = 1 if wrkstat <= 2
replace work = 0 if wrkstat > 2 & wrkstat < .

ttest hope, by(work)
esize twosample hope, by(work)

recode hapmar (3 = 1 "Not too happy") (1 = 3 "Very happy"), pre(new) label(new)
recode health (4 = 1 "Poor") (3 = 2 "Fair") (2 = 3 "Good") (1 = 4 "Excellent"), ///
pre(new) label(new)
recode coneduc (3 = 1 "Harly any") (1 = 3 "A great deal"), ///
      pre(new) label(new)


pwcorr hope cesd1 newhapmar newhealth newconeduc, obs sig

*******************************************************
* PCF analysis using 2006 GSS national priorities data
*******************************************************
use gss2006_chapter12_selected, clear
codebook natspac natenvir natheal natcity natcrime natdrug nateduc natrace ///
	natarms natfare natroad natsoc natchld natsci, compact
recode natspac natenvir natheal natcity natcrime natdrug nateduc natrace ///
	natarms natfare natroad natsoc natchld natsci ///
	(1=3 "Too little")(2=2 "About right") (3=1 "Too much"), pre(r) label(revnat)
factor rnatspac rnatenvir rnatheal rnatcity rnatcrime rnatdrug ///
	rnateduc rnatrace rnatarms rnatfare rnatroad rnatsoc rnatchld rnatsci, pcf
screeplot
rotate
rotate, promax
estat common
factor rnatenvir rnatheal rnatcity rnatcrime rnatdrug rnateduc rnatrace ///
	rnatfare rnatsoc rnatchld, pcf
predict libfscore, norotate
egen libmean = rowmean(rnatenvir rnatheal rnatcity rnatcrime rnatdrug ///
	rnateduc rnatrace rnatfare rnatsoc rnatchld)

