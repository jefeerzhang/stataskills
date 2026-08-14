use flourishing_bmi, clear
regress bmi age children income educ quickfood, beta

use flourishing_bmi

sem bmi <- age children incomeln educ quickfood

sem bmi <- age children incomeln educ quickfood, standardized

sem bmi <- age children incomeln educ quickfood, method(mlmv) standardized

estat eqgof

misstable summarize bmi age children incomeln educ quickfood, generate(miss_)

sem bmi age children incomeln educ quickfood, method(mlmv)
estat eqgof
recode bmi (0/29.999=0) (30/60=1), gen(obese)
logit obese age children incomeln educ quickfood
listcoef
glm obese age children incomeln educ quickfood, family(binomial) link(logit)
glm, eform
summarize age incomeln educ quickfood if !missing(age,incomeln,educ,quickfood,obese)
display exp(.029*6.419)
display exp(-.610*.758)
display exp(-.201*1.505)
display exp(.260*1.182)
