version 19.5
* ==== VERIFY CONTRACT ====
* skill:    stata-basics
* chapter:  ch3
* data:     relate.dta;firstsurvey_chapter4.dta
* checks:   missing+reverse+scale
* ============================
* ---- ch3 缺失值处理 + 反向编码 + 量表构建 ----
use relate, clear
rename R0000100-R3828700, lower
mvdecode _all, mv(-5=.a\-4=.b\-3=.c\-2=.d\-1=.e)
recode r3483700 r3483900 r3485300 r3485500 (0=4)(1=3)(2=2)(3=1)(4=0), generate(momcritr momblamer dadcritr dadblamer)
tabulate momcritr r3483700
clonevar mompraise = r3483600
clonevar momhelp = r3483800
clonevar dadpraise = r3485200
clonevar dadhelp = r3485400
egen float mommissing = rowmiss(mompraise momcritr momhelp momblamer)
egen float mommean = rowmean(mompraise momcritr momhelp momblamer)
tabulate mommissing
summarize mommean

* ---- ch4 do-file 与 list ----
use firstsurvey_chapter4, clear
summarize
list gender education prison in 1/5, nolabel
numlabel _all, add
list gender education prison in 1/5
