
libname outlib "../../synthesize/couples";

proc contents data=outlib.syn_couples1 (keep=f_:) out=mycontents (keep=name);
data _null_;
  set mycontents;
  call symput("var" || compress(put(_n_,4.)),substr(name,3,length(name)-2));
  call symput("numvars",compress(put(_n_,4.)));
run;
%macro makelist;
  %global varlist;
  %let varlist=;
  %do i=1 %to &numvars.;
    %let varlist=&varlist. &&var&i..;
  %end;
%mend;
%makelist;
%put VARLIST=&varlist.;

%macro rename(prefix);
  %do i=1 %to &numvars.;
    &&var&i..=&prefix.&&var&i..;
  %end;
%mend;
data outlib.comparison_couples (keep=&varlist. spouse_personid male);
  set outlib.syn_couples1;
  if m_personid>0 and f_personid>0 then do;
    %rename(m_);
    spouse_personid=f_personid;
    male=1;
    output;
    %rename(f_);
    spouse_personid=m_personid;
    male=0;
    output;
  end;
run;
proc print data=outlib.comparison_couples (obs=20);





