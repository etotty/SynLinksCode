

*** need to specify implicate before including config.sas;
%let implicate=1;
%include "filelocations.sas";
%include "kde_support.sas";
%include "config2.sas";

%macro stack;
data stacked_syn;
  set %do m=1 %to 4; implib.&impfile.&m. (in=a&m.) %end;;
  %do m=1 %to 4;
    if a&m. then do;
      if personid>0 then personid=personid+(&m.*0.1);
      if spouse_personid>0 then spouse_personid=spouse_personid+(&m.*0.1);
      if mom_personid>0 then mom_personid=mom_personid+(&m.*0.1);
    end;
  %end;
run;
%mend;
%stack;

%macro hh_stats(indat,suffix=);
  data kids (keep=personid hhid type);
    set &indat. (keep=personid mom_personid rename=(mom_personid=hhid) where=(hhid>0));
    type=3;
  run;
  proc sort data=kids;
    by hhid personid;
  run;
  data husbands (keep=personid hhid type);
    set &indat. (keep=personid spouse_personid male rename=(spouse_personid=hhid) where=(hhid>0 and male=1));
    type=2;
  run;
  proc sort data=husbands;
    by hhid personid;
  run;
  data householders;
    set kids (keep=hhid) husbands (keep=hhid);
  run;
  proc sort data=householders;
    by hhid;
  run;
  data householders (keep=personid hhid type);
    set householders;
    by hhid;
    personid=hhid;
    type=1;
    if last.hhid then output;
  run;
  data households;
    set householders husbands kids;
  run;
  proc sort data=households;
    by personid;
  run;
  proc sort data=&indat. out=indat;
    by personid;
  run;

  %let vars=sipp_birthdate male race hispanic foreign_born educ_5cat total_der_fica_2009;
  data households;
    merge households (in=aa) indat (in=bb keep=personid &vars.);
    by personid;
    if aa;
  run;
  proc sort data=households;
    by hhid type;
  run;
  data households&suffix.;
    set households;
    by hhid type;
    retain hh_size white_count black_count other_count num_par_coll num_par_work single foreign_count;
    if first.hhid then do;
      hh_size=0;
      white_count=0;
      black_count=0;
      other_count=0;
      num_par_coll=0;
      num_par_work=0;
      single=1;
      foreign_count=0;
    end;
    hh_size=hh_size+1;
    if race=1 then white_count=white_count+1;
    if race=2 then black_count=black_count+1;
    if race=3 then other_count=other_count+1;
    if educ_5cat ge 4 and type le 2 then num_par_coll=num_par_coll+1;
    if total_der_fica_2009>0 and type le 2 then num_par_work=num_par_work+1;
    if type=2 then single=0;
    foreign_count=foreign_count+foreign_born;
    if last.hhid then do;
      num_races=0;
      if white_count>0 then num_races=num_races+1;
      if black_count>0 then num_races=num_races+1;
      if other_count>0 then num_races=num_races+1;
      source=&suffix.;
      output;
    end;
  run;

%mend;
%hh_stats(estlib.&estfile.,suffix=0);
%hh_stats(stacked_syn,suffix=1);
  
  data households;
    set households0 households1;
    stat=1;
    if source=0 then implicate=0;
    else implicate=round(10*(personid-floor(personid)),1);
    educ_type=put(single,z1.) || put(num_par_coll,z1.);
    work_type=put(single,z1.) || put(num_par_work,z1.);
    if foreign_count=0 then foreign_type=0;
    else if foreign_count<hh_size then foreign_type=1;
    else foreign_type=2;
    hh_sizecat=min(5,hh_size);
  run;
  proc freq data=households;
    tables hh_sizecat*implicate /norow nopercent out=table1;
    tables num_races*implicate /norow nopercent out=table2;
    tables educ_type*implicate /norow nopercent out=table3;
    tables work_type*implicate /norow nopercent out=table4;
    tables foreign_type*implicate /norow nopercent out=table5;
  run;

%macro combine(tnum, tvar);
  data table&tnum.;
    set table&tnum. end=lastobs;
    retain n0 n1-n4 0;
    if implicate=1 then n1=n1+count;
    else if implicate=2 then n2=n2+count;
    else if implicate=3 then n3=n3+count;
    else if implicate=4 then n4=n4+count;
    else n0=n0+count;
    if implicate>0 then source=1; else source=0;
    if lastobs then call symput("n0",compress(put(n0,12.)));
    if lastobs then call symput("n1",compress(put(n1,12.)));
    if lastobs then call symput("n2",compress(put(n2,12.)));
    if lastobs then call symput("n3",compress(put(n3,12.)));
    if lastobs then call symput("n4",compress(put(n4,12.)));
  run;
  data table&tnum.;
    set table&tnum.;
    if implicate=1 then q=(count/&n1.);
    else if implicate=2 then q=(count/&n2.);
    else if implicate=3 then q=(count/&n3.);
    else if implicate=4 then q=(count/&n4.);
    else q=(count/&n0.);
    if implicate=1 then u=q*(1-q)/&n1.;
    else if implicate=2 then u=q*(1-q)/&n2.;
    else if implicate=3 then u=q*(1-q)/&n3.;
    else if implicate=4 then u=q*(1-q)/&n4.;
    else u=q*(1-q)/&n0.;
  run;
  proc means data=table&tnum. noprint;
    var q u;
    class &tvar. source;
    types &tvar.*source;
    output out=stats mean(q)=q var(q)=b mean(u)=u n(q)=r;
  run;
  data stats;
    set stats;
    if source=0 then do;
      T=u;
      dof=&n0.-1;
      lb95=q+((sqrt(T))*tinv(0.025,dof));
      ub95=q+((sqrt(T))*tinv(0.975,dof));
    end;
    else do;
      T=(b/r)+u;
      dof=(r-1)*((1+(u/(b/r)))**2);
      lb95=q+((sqrt(T))*tinv(0.025,dof));
      ub95=q+((sqrt(T))*tinv(0.975,dof));
    end;
    q=round(q,10**(floor(log10(abs(q)))-3));
    lb95=round(lb95,10**(floor(log10(abs(lb95)))-3));
    ub95=round(ub95,10**(floor(log10(abs(ub95)))-3));
  run;
  proc print data=stats;
    var &tvar. source q lb95 ub95;* u b r T dof;
    title "Table of &tvar. by source";
  run;

%mend;
%combine(1,hh_sizecat);
%combine(2,num_races);
%combine(3,educ_type);
%combine(4,work_type);
%combine(5,foreign_type);







