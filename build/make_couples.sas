
libname b "./";

proc contents data=b.person_file (drop=personid spouse_personid mom_personid) out=varnames (keep=name) noprint;
data _null_;
  set varnames end=lastobs;
  call symput("var" || compress(put(_n_,4.)),name);
  if lastobs then call symput("nvars",compress(put(_n_,4.)));
run;
%macro myrename(prefix);
  %do i=1 %to &nvars.;
    &prefix.&&var&i..=&&var&i..;
  %end;
%mend;
data males (keep=f_personid m_:) females (keep=m_personid f_:);
  set b.person_file;
  if linked_couple=1 then do;
    if male=0 then do;
      %myrename(f_);
      m_personid=spouse_personid;
      f_personid=personid;
      output females;
    end;
    else if male=1 then do;
      %myrename(m_);
      f_personid=spouse_personid;
      m_personid=personid;
      output males;
    end;
  end;
run;
proc sort data=males;
  by f_personid m_personid;
run;
proc sort data=females;
  by f_personid m_personid;
run;
data b.couples;
  merge males (in=aa) females (in=bb);
  by f_personid m_personid;
  if aa & bb;
run;  












