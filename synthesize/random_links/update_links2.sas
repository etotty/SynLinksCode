
%include "filelocations.sas";

%macro update;

%do m=1 %to 4;

proc sort data=estlib.&estfile. out=temp;
  by personid;
run;
proc sort data=outlib.syn0_spouse_xwalk&m. out=xwalk1 (keep=m_personid f_personid);
  by m_personid;
run;
proc sort data=outlib.syn0_spouse_xwalk&m. out=xwalk2 (keep=f_personid m_personid);
  by f_personid;
run;
data xwalk;
  set xwalk1 (rename=(m_personid=personid f_personid=spouse_personid))
      xwalk2 (rename=(f_personid=personid m_personid=spouse_personid));
run;
proc sort data=xwalk;
  by personid;
run;
data outlib.syn0_person&m.;
  merge temp (in=aa drop=spouse_personid linked_couple) xwalk (in=bb);
  by personid;
  if aa;
  if bb then linked_couple=1; else linked_couple=0;
run;

proc contents data=estlib.couples (keep=f_:) out=temp (keep=name) noprint;
data _null_;
  set temp;
  call symput("var" || compress(put(_n_,4.)),substr(name,3));
  call symput("n",compress(put(_n_,4.)));
run;
data outlib.syn2_person&m. (drop=m_: f_:);
  set implib2.syn_couples&m.;
  linked_couple=1;
  spouse_personid=m_personid;
  %do i=1 %to &n.;
    &&var&i..=f_&&var&i..;
  %end;
  output;
  spouse_personid=f_personid;
  %do i=1 %to &n.;
    &&var&i..=m_&&var&i..;
  %end;
  output;
run;

%end;

%mend;
%update;




