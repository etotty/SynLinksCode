
%include "filelocations.sas";

proc sort data=estlib.&estfile. (keep=personid spouse_personid) out=temp0;
  by personid spouse_personid;
run;

%macro loop(implicates);

%do m=1 %to &implicates.;

proc sort data=outlib.syn0_spouse_xwalk&m. out=temp&m. (rename=(m_personid=personid f_personid=spouse_personid));
  by m_personid f_personid;
run;
data check&m.;
  merge temp&m. (in=aa) temp0 (in=bb);
  by personid spouse_personid;
  if aa;
  if bb then flag=1; else flag=0;
run;
proc freq data=check&m.;
  tables flag;
run;

%end;

%mend;
%loop(4);





