

*** need to specify implicate before including config.sas;
%let implicate=1;
%include "filelocations.sas";
%include "config1.sas";
%include "kde_support.sas";

%macro stack(basename,xwalk,suffix=);
************************************;
data stacked_syn&suffix.;
  set %do m=1 %to 4; &basename.&m. (in=a&m.) %end;;
  %do m=1 %to 4;
    if a&m. then do;
      if personid>0 then personid=personid+(&m.*0.1);
      if spouse_personid>0 then spouse_personid=spouse_personid+(&m.*0.1);
      if mom_personid>0 then mom_personid=mom_personid+(&m.*0.1);
    end;
  %end;
run;
proc sort data=stacked_syn&suffix.;
  by personid;
run;
%if &xwalk.=0 %then %do;
%end;
%else %do;
  data stacked_xwalk&suffix.;
    set %do m=1 %to 4; &xwalk.&m. (in=a&m.) %end;;
    %do m=1 %to 4;
      if a&m. then do;
        if m_personid>0 then m_personid=m_personid+(&m.*0.1);
        if f_personid>0 then f_personid=f_personid+(&m.*0.1);
      end;
    %end;
  run;
%end;
************************************;
%mend;
%stack(implib.&impfile.,outlib2.syn_spouse_xwalk,suffix=1);
%stack(outlib2.syn0_person,outlib2.syn0_spouse_xwalk,suffix=2);
%stack(outlib.syn_couples,0,suffix=3);

%macro pair_stats(indat,xwalk,suffix=);
  %if &xwalk.=0 %then %do;
    data couples;
      set &indat.;
      diff=(f_sipp_birthdate-m_sipp_birthdate)/365.25;
    run;
  %end;
  %else %do;
    proc sort data=&xwalk. (keep=m_personid f_personid) out=couples;
      by m_personid;
    run;
    data couples;
      merge couples (in=aa) &indat. (in=bb keep=personid sipp_birthdate
        rename=(personid=m_personid sipp_birthdate=m_sipp_birthdate));
      by m_personid;
      if aa & bb;
    run;
    proc sort data=couples;
      by f_personid;
    run;
    data couples;
      merge couples (in=aa) &indat. (in=bb keep=personid sipp_birthdate
        rename=(personid=f_personid sipp_birthdate=f_sipp_birthdate));
      by f_personid;
      if aa & bb;
      diff=(f_sipp_birthdate-m_sipp_birthdate)/365.25;
    run;
  %end;

  proc kde data=couples;
    univar diff / out=kde_&suffix. gridl=-20 gridu=20 ng=41;
  run;
  proc means data=couples print n mean std min p1 p5 p10 q1 median q3 p90 p95 p99 max;
    var diff;
    title "&indat.";
  run;

  %if &suffix.=0 %then %do;
    %kde_support(couples,diff,kde_&suffix.,0);
  %end;

%mend;

data temp_xwalk (keep=m_personid f_personid);
  set estlib.&estfile (keep=male personid spouse_personid where=(spouse_personid>0));
  if male=0 then do;
    f_personid=personid;
    m_personid=spouse_personid;
  end;
  else do;
    m_personid=personid;
    f_personid=spouse_personid;
  end;
run;

*pair_stats(estlib.couples,0,suffix=0);
%pair_stats(estlib.&estfile.,temp_xwalk,suffix=0);

*pair_stats(implib.&impfile.1,outlib.syn_spouse_xwalk1,suffix=1);
*pair_stats(outlib.syn0_person1,outlib.syn0_spouse_xwalk1,suffix=2);
*pair_stats(outlib.syn_couples1,0,suffix=3);
%pair_stats(stacked_syn1,stacked_xwalk1,suffix=1);
%pair_stats(stacked_syn2,stacked_xwalk2,suffix=2);
%pair_stats(stacked_syn3,0,suffix=3);

data kde;
  set kde_0 (rename=(density=density0));
  set kde_1 (rename=(density=density1));
  set kde_2 (rename=(density=density2));
  set kde_3 (rename=(density=density3));
  retain fmax 0;
  fmax=0.01*ceil(100*max(fmax,density0,density1,density2,density3));
  call symput("fmax",compress(put(fmax,8.2)));
  call symput("fstep",compress(put(fmax/10,8.3)));
run;
%put FMAX=&fmax.;
proc plot data=kde;
  plot density0*value="*" density1*value="o" /overlay;
run;

  filename out ".";
  goptions reset=global device=png gsfname=out xmax=5.5 ymax=4.25;
  symbol1 color=red value=none width=2 interpol=spline;
  symbol2 color=green value=none width=2 interpol=spline;
  symbol3 color=blueviolet value=none width=2 interpol=spline;
  symbol4 color=yelloworange value=none width=2 interpol=spline;
  legend1 label=none position=(top right inside) mode=share
    value=("OrigData, OrigLinks" "SynData, SynLinks" "SynData, OrigLinks" "OrigData, SynLinks") across=1;
  
  axis1 order=(-20 to 20 by 5);
  axis2 order=(0 to &fmax. by &fstep.);

  proc gplot data=kde;
    plot density0*value density1*value density2*value density3*value
      /overlay haxis=axis1 vaxis=axis2 name="spouses_agediff" legend=legend1;
  run;
  quit;


