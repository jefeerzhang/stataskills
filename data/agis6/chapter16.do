clear
use "attitude.dta"
fre dn2 dn4 dn5 dn7 dn10

* Rasch Model with 1 parameter estimated (difficulty)
irt 1pl dn2 dn4 dn5 dn7 dn10
estat report, byparm sort(b)
irtgraph icc, blocation 

* each item gives most information around its difficulty score
irtgraph iif
irtgraph tif, se
predict rasch_score, latent
summarize rasch_score

* testing whether a 1 or 2 parameter model is needed
irt 1pl dn2 dn4 dn5 dn7 dn10 
estimates store rasch
irt 2pl dn2 dn4 dn5 dn7 dn10 
lrtest rasch

*IRT 2PL model
irt 2pl dn2 dn4 dn5 dn7 dn10
irtgraph icc, blocation 
irtgraph iif
irtgraph tif, se
predict irt_score, latent
summarize rasch_score irt_score
fre n2 n4 n5 n7 n10
irt grm n2 n4 n5 n7 n10
irtgraph icc n4, blocation
irtgraph iif

use attitude, clear
irt grm n2 n4 n5 n7 n10
irtgraph tif, se

