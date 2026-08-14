* c3.do
* This do-file does the analysis for chapter 3
use relate, clear

rename R0000100-R3828700, lower


describe r3483600 r3483700 r3483800 r3483900
codebook, compact

codebook r3483600
mvdecode _all, mv(-5=.a\-4=.b\-3=.c\-2=.d\-1=.e)
label define often  0 "Never" 1 "Rarely" 2 "Sometimes" 3 "Usually" 4 "Always"
label define often .a "Noninterview" .b "Valid skip" .c "Invalid skip", add
label define often .d "Don't know" .e "Refusal", add
*label define often_r  4 "Never" 3 "Rarely" 2 "Sometimes" 1 "Usually" 0 "Always"
*label define often_r .a "Noninterview" .b "Valid skip" .c "Invalid skip", add
*label define often_r .d "Don't know" .e "Refusal", add
label values r3483600 often
label values r3483800 often
label values r3485200 often
label values r3485400 often

label variable r3483600 "Mother praises child for doing well"
label variable r3483700 "Mother criticizes child's ideas"
label variable r3483800 "Mother helps child with what is important to child"
label variable r3483900 "Mother blames child for problems"
label variable r3485200 "Father praises child for doing well"
label variable r3485300 "Father criticizes child's ideas"
label variable r3485400 "Father helps child with what is important to child"
label variable r3485500 "Father blames child for problems"
codebook r3483600
recode r3483700 r3483900 r3485300 r3485500 (0=4) (1=3) (2=2) (3=1) (4=0), ///
	generate(momcritr momblamer dadcritr dadblamer)
label variable momcritr "Mother criticizes child's ideas, reverses r3483700"
label variable momblamer "Mother blames child for problems, reverses r3483900"
label variable dadcritr "Father criticizes child's ideas, reverses r3485300"
label variable dadblamer "Father blames child for problems, reverses r3485500"
tabulate momcritr r3483700
label define often_r 4 "Never" 3 "Rarely" 2 "Sometimes" 1 "Usually" 0 "Always" ///
    .a "Noninterview" .b "Valid skip" .c "Invalid skip" .d "Don't know" ///
    .e "Refusal"
label values momcritr momblamer dadcritr dadblamer often_r
clonevar mompraise = r3483600
clonevar momhelp = r3483800
clonevar dadpraise = r3485200
clonevar dadhelp = r3485400
clonevar id = r0000100
clonevar sex = r3828700
clonevar age = r3828100
generate facritr = 4 - r3485300
tabulate facritr r3485300, miss nolabel
generate ymomrelate = mompraise + momcritr + momhelp + momblamer
generate ydadrelate = dadpraise + dadcritr + momhelp + momblamer
egen float mommissing = rowmiss(mompraise momcritr momhelp momblamer)
tabulate mommissing
egen float mommeanb = rowmean(mompraise momcritr momhelp momblamer) ///
  if mommissing < 2
drop r0000100 r3483600 r3483700 r3483800 r3483900 r3485200 r3485300 r3485400 ///
   r3485500 r3828100 r3828700
