* chapter1.do
* You will learn how to create and use a *.do file in chapter 4.
* This file reproduces all the results shown in Chapter 1
sysuse cancer, clear
describe
summarize
histogram age
histogram age, width(2.5) start(45) frequency ///
	title(Age Distribution of Participants in Cancer Study) ///
	note(Data: Sample cancer dataset) legend(on) scheme(s1mono)
histogram age, width(5) start(45) frequency ///
      title(Age Distribution of Participants in Cancer Study) ///
      note(Data: Sample cancer dataset) legend(on) scheme(s1mono)
