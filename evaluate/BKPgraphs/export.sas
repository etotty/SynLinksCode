
libname here "./";
libname data "../../build";
libname syndata "../../synthesize/persons";
libname syndata2 "../../synthesize/couples";
libname syndata3 "../../synthesize/random_links";

proc export data=data.person_file file="../../build/person_file.dta" replace;
run;
proc export data=syndata.syn_person1 file="../../synthesize/persons/syn_person.dta" replace;
run;
proc export data=syndata2.comparison_couples file="../../synthesize/couples/comparison_couples.dta" replace;
run;
proc export data=syndata3.syn0_person1 file="../../synthesize/random_links/syn0_person.dta" replace;
run;
proc export data=here.comparison_v6 file="./comparison_v6.dta" replace;
run;
proc export data=here.comparison_v7 file="./comparison_v7.dta" replace;
run;


