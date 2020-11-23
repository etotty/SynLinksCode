
%include "filelocations.sas";

%macro update;

proc sort data=implib.&impfile.&implicate. out=temp;
  by personid;
run;

proc sort data=outlib.syn_spouse_xwalk&implicate. out=xwalk1 (keep=m_personid f_personid);
  by m_personid;
run;
proc sort data=outlib.syn_spouse_xwalk&implicate. out=xwalk2 (keep=f_personid m_personid);
  by f_personid;
run;
data xwalk;
  set xwalk1 (rename=(m_personid=personid f_personid=spouse_personid))
      xwalk2 (rename=(f_personid=personid m_personid=spouse_personid));
run;
proc sort data=xwalk;
  by personid;
run;
data temp;
  merge temp (in=aa drop=spouse_personid linked_couple) xwalk (in=bb);
  by personid;
  if aa;
  if bb then linked_couple=1; else linked_couple=0;
run;

proc sort data=outlib.syn_momchild_xwalk&implicate. out=xwalk (keep=m_personid k_personid);
  by k_personid;
run;
data implib.&impfile.&implicate.;
  merge temp (in=aa drop=mom_personid) xwalk (in=bb rename=(k_personid=personid m_personid=mom_personid));
  by personid;
  if aa;
run;

%mend;
%let implicate=1;
%update;
%let implicate=2;
%update;
%let implicate=3;
%update;
%let implicate=4;
%update;




