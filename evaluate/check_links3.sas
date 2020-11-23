

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

%macro pair_stats(indat,suffix=);
    data xwalk;
      set &indat. (keep=personid mom_personid rename=(personid=k_personid mom_personid=m_personid) where=(m_personid>0));
    run;
  proc sort data=xwalk (keep=m_personid) out=moms;
    by m_personid;
  run;
  data moms;
    set moms;
    by m_personid;
    if last.m_personid then output;
  run;
  proc sort data=xwalk (keep=k_personid m_personid) out=kids;
    by k_personid;
  run;
  proc sort data=&indat. out=indat;
    by personid;
  run;

    data temp_m (keep=m_personid m_sipp_birthdate)
         temp_k (keep=m_personid k_personid k_sipp_birthdate);
      merge indat (keep=personid sipp_birthdate in=a0) moms (rename=(m_personid=personid) in=am) kids (rename=(k_personid=personid m_personid=mom_personid) in=ak);
      by personid;
      if a0;
      m_sipp_birthdate=sipp_birthdate;
      k_sipp_birthdate=sipp_birthdate;
      if am then do;
        m_personid=personid;
        output temp_m;
      end;
      if ak then do;
        m_personid=mom_personid;
        k_personid=personid;
        output temp_k;
      end;
    run;
    proc sort data=temp_m;
      by m_personid;
    run;
    proc sort data=temp_k;
      by m_personid k_personid;
    run;
    data pairs;
      merge temp_m (in=mm) temp_k (in=kk);
      by m_personid;
      if mm & kk;
      diff1=(k_sipp_birthdate-m_sipp_birthdate)/365.25;
    run;
proc print data=pairs (obs=20);
    proc kde data=pairs;
      univar diff1 / out=kde1_&suffix. gridl=12 gridu=52 ng=41;
    run;
    data temp2 (keep=diff2) temp3 (keep=diff3);
      set pairs;
      by m_personid k_personid;
      retain count 0;
      retain last_bd oldest;
      if first.m_personid then do;
        count=0;
        oldest=k_sipp_birthdate;
        last_bd=.;
      end;
      else do;
        diff2=(k_sipp_birthdate-last_bd)/365.25;
        output temp2;
      end;
      count=count+1;
      if last.m_personid and count>1 then do;
        diff3=(k_sipp_birthdate-oldest)/365.25;
        output temp3;
      end;
      last_bd=k_sipp_birthdate;
    run;
    proc kde data=temp2;
      univar diff2 / out=kde2_&suffix. gridl=0 gridu=5 ng=41;
    run;
    proc kde data=temp3;
      univar diff3 / out=kde3_&suffix. gridl=0 gridu=5 ng=41;
    run;

  %if &suffix.=0 %then %do;
    %kde_support(pairs,diff1,kde1_&suffix.,0);
    %kde_support(temp2,diff2,kde2_&suffix.,0);
    %kde_support(temp3,diff3,kde3_&suffix.,0);
  %end;

%mend;
%pair_stats(estlib.&estfile.,suffix=0);
*pair_stats(implib.&impfile.1,suffix=1);
%pair_stats(stacked_syn,suffix=1);

data kde1;
  set kde1_0 (rename=(density=density0));
  set kde1_1 (rename=(density=density1));
  retain fmax 0;
  fmax=max(fmax,density0,density1);
  fmax=0.01*ceil(100*max(fmax,density0,density1));
  call symput("fmax1",compress(put(fmax,8.2)));
  call symput("fstep1",compress(put(fmax/10,8.3)));
run;
proc plot data=kde1;
  plot density0*value="*" density1*value="o" /overlay;
run;

data kde2;
  set kde2_0 (rename=(density=density0));
  set kde2_1 (rename=(density=density1));
  retain fmax 0;
  fmax=max(fmax,density0,density1);
  fmax=0.01*ceil(100*max(fmax,density0,density1));
  call symput("fmax2",compress(put(fmax,8.2)));
  call symput("fstep2",compress(put(fmax/10,8.3)));
run;
proc plot data=kde2;
  plot density0*value="*" density1*value="o" /overlay;
run;

data kde3;
  set kde3_0 (rename=(density=density0));
  set kde3_1 (rename=(density=density1));
  retain fmax 0;
  fmax=max(fmax,density0,density1);
  fmax=0.01*ceil(100*max(fmax,density0,density1));
  call symput("fmax3",compress(put(fmax,8.2)));
  call symput("fstep3",compress(put(fmax/10,8.3)));
run;
proc plot data=kde3;
  plot density0*value="*" density1*value="o" /overlay;
run;



  filename out ".";
  goptions reset=global device=png gsfname=out xmax=5.5 ymax=4.25;
  symbol1 color=red value=none width=2 interpol=spline;
  symbol2 color=green value=none width=2 interpol=spline;
  legend1 label=none position=(top right inside) mode=share value=("OrigData, OrigLinks" "SynData, SynLinks") across=1;
  
  axis1 order=(12 to 47 by 5);
  axis2 order=(0 to &fmax1. by &fstep1.);
  proc gplot data=kde1;
    plot density0*value density1*value
      /overlay haxis=axis1 vaxis=axis2 name="momkid_agediff" legend=legend1;
  run;

  axis1 order=(0 to 5 by 1);
  axis2 order=(0 to &fmax2. by &fstep2.);
  proc gplot data=kde2;
    plot density0*value density1*value
      /overlay haxis=axis1 vaxis=axis2 name="sibling_agediff1" legend=legend1;
  run;

  axis1 order=(0 to 5 by 1);
  axis2 order=(0 to &fmax3. by &fstep3.);
  proc gplot data=kde3;
    plot density0*value density1*value
      /overlay haxis=axis1 vaxis=axis2 name="sibling_agediff2" legend=legend1;
  run;

  quit;

