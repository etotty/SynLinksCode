
%include "macros/fastbb.sas";
%include "macros/transform_w.sas";
%include "macros/extract_pc.sas";
%include "kde_support.sas";

%include "filelocations.sas";
%include "config1.sas";
%let num_factors=10;
%let xrec=1;

%macro input2royston;

  *** A couple macros to use in the main loop over panels and states;
  %macro add_prefix1(prefix,startlist);
    %local prefix startlist lnum lterm;
    %let lnum=1;
    %do %until("%scan(&startlist.,&lnum.)"="");
      %let lterm=%scan(&startlist.,&lnum.);
      &lterm.=&prefix.&lterm.
      %let lnum=%eval(&lnum.+1);
    %end;
  %mend;
  %macro add_prefix2(prefix,startlist);
    %local prefix startlist lnum lterm;
    %let lnum=1;
    %do %until("%scan(&startlist.,&lnum.)"="");
      %let lterm=%scan(&startlist.,&lnum.);
      &prefix.&lterm.
      %let lnum=%eval(&lnum.+1);
    %end;
  %mend;

  data
    temp1_a (keep=&idvar. &byvar. &vars_men. rename=(%add_prefix1(m_,&idvar. &vars_men.)))
    temp1_b (keep=&idvar. &byvar. &vars_women. rename=(%add_prefix1(f_,&idvar. &vars_women.)))
    temp1_xwalk (keep=&idvar. spouse_&idvar. rename=(&idvar.=m_&idvar. spouse_&idvar.=f_&idvar.));
    set estlib.&estfile. (where=(linked_couple=1));
    %make_vars;
    %add_zero;
    if male=1 then do;
      output temp1_a;
      output temp1_xwalk;
    end;
    else output temp1_b;
  run;
  %let ren_vars_men=%add_prefix2(m_,&vars_men.);
  %let ren_vars_women=%add_prefix2(f_,&vars_men.);

  data temp_both_a;
    set temp1_a;
  run;
  %extract_pc(temp1_a,temp_both_a,&ren_vars_men.,&num_factors.,basename=PCa,interact=0);
  data temp1_a;
    set temp_both_a;
  run;

  data temp_both_b;
    set temp1_b;
  run;
  %extract_pc(temp1_b,temp_both_b,&ren_vars_women.,&num_factors.,basename=PCb,interact=0);
  data temp1_b;
    set temp_both_b;
  run;

  data pre_couples;
    set temp1_b (drop=rot);
  run;
  proc sort data=pre_couples;
    by f_personid;
  run;
  proc sort data=temp1_xwalk;
    by f_personid;
  run;
  data pre_couples;
    merge pre_couples (in=aa) temp1_xwalk (in=bb);
    by f_personid;
    if aa & bb;
  run;
  proc sort data=pre_couples;
    by m_personid;
  run;
  proc sort data=temp1_a;
    by m_personid;
  run;
  data pre_couples;
    merge pre_couples (in=aa) temp1_a (drop=rot in=bb);
    by m_personid;
    if aa & bb;
  run;

  %let new_vars_men=;
  %let new_vars_women=;
  %do j=1 %to &num_factors.;
    %let new_vars_men=&new_vars_men. PCa&j.;
    %tfile(PCa&j.,temp1_a,tmale&j.);
    %transform(PCa&j.,temp1_a,tmale&j.);
    %let new_vars_women=&new_vars_women. PCb&j.;
    %tfile(PCb&j.,temp1_b,tfemale&j.);
    %transform(PCb&j.,temp1_b,tfemale&j.);
  %end;

  data couples;
    set temp1_b (drop=rot);
  run;
  proc sort data=couples;
    by f_personid;
  run;
  proc sort data=temp1_xwalk;
    by f_personid;
  run;
  data couples;
    merge couples (in=aa) temp1_xwalk (in=bb);
    by f_personid;
    if aa & bb;
  run;
  proc sort data=couples;
    by m_personid;
  run;
  proc sort data=temp1_a;
    by m_personid;
  run;
  data couples;
    merge couples (in=aa) temp1_a (drop=rot in=bb);
    by m_personid;
    if aa & bb;
  run;
  proc print data=couples (obs=10);

  proc export data=couples
    outfile="./couples_new.csv"
    dbms=csv 
    replace;
  run;

  proc kde data=pre_couples;
    univar PCa1 / out=kde0_a1 gridl=-3 gridu=3 ng=61;
  run;
  proc kde data=couples;
    univar PCa1 / out=kde1_a1 gridl=-3 gridu=3 ng=61;
  run;
  data kde0_a1;
    set kde0_a1;
    retain fmax 0;
    fmax=max(fmax,density);
    fmax=0.01*ceil(100*max(fmax,density));
    call symput("fmax",compress(put(fmax,8.2)));
    call symput("fstep",compress(put(fmax/10,8.3)));
  run;
  data kde1_a1;
    set kde1_a1;
    density2=pdf("NORMAL",value,0,1);
    retain fmax &fmax.;
    fmax=max(fmax,density,density2);
    fmax=0.01*ceil(100*max(fmax,density,density2));
    call symput("fmax",compress(put(fmax,8.2)));
    call symput("fstep",compress(put(fmax/10,8.3)));
  run;
  proc kde data=pre_couples;
    univar PCb1 / out=kde0_b1 gridl=-3 gridu=3 ng=61;
  run;
  data kde0_b1;
    set kde0_b1;
    retain fmax &fmax.;
    fmax=max(fmax,density);
    fmax=0.01*ceil(100*max(fmax,density));
    call symput("fmax",compress(put(fmax,8.2)));
    call symput("fstep",compress(put(fmax/10,8.3)));
  run;
  proc kde data=couples;
    univar PCb1 / out=kde1_b1 gridl=-3 gridu=3 ng=61;
  run;
  data kde1_b1;
    set kde1_b1;
    density2=pdf("NORMAL",value,0,1);
    retain fmax &fmax.;
    fmax=max(fmax,density,density2);
    fmax=0.01*ceil(100*max(fmax,density,density2));
    call symput("fmax",compress(put(fmax,8.2)));
    call symput("fstep",compress(put(fmax/10,8.3)));
  run;

  proc kde data=pre_couples;
    bivar PCa1 PCb1 / out=kde0_both gridl=-3 gridu=3 ng=61;
  run;
  proc kde data=couples;
    bivar PCa1 PCb1 / out=kde1_both gridl=-3 gridu=3 ng=61;
  run;
  data kde0_both;
    set kde0_both end=lastobs;
    retain fmax 0;
    fmax=max(fmax,density);
    fmax=0.01*ceil(100*max(fmax,density));
    call symput("fmaxb",compress(put(fmax,8.2)));
    call symput("fstepb",compress(put(fmax/10,8.3)));
if lastobs then put "fmax=" fmax;
  run;
  data kde1_both;
    set kde1_both end=lastobs;
    retain fmax &fmaxb.;
    fmax=max(fmax,density);
    fmax=0.01*ceil(100*max(fmax,density));
    call symput("fmaxb",compress(put(fmax,8.2)));
    call symput("fstepb",compress(put(fmax/10,8.3)));
if lastobs then put "fmax=" fmax;
  run;
%put fmax=&fmaxb.;

  proc corr data=couples outp=sigma noprint;
    var PCa1 PCb1;
  run;
  data sigma (keep=mu_a1 mu_b1 sigma_a1 sigma_b1 rho);
    set sigma end=lastobs;
    retain mu_a1 mu_b1 sigma_a1 sigma_b1 rho;
    if _type_="MEAN" then do;
      mu_a1=PCa1;
      mu_b1=PCb1;
    end;
    else if _type_="STD" then do;
      sigma_a1=PCa1;
      sigma_b1=PCb1;
    end;
    else if _type_="CORR" then rho=PCa1;
    if lastobs then output;
  run;
  data truenorm;
    set sigma; seed=0;
    do i=1 to 1000000;
      call rannor(seed,z1);
      call rannor(seed,z2);
      x=mu_a1+(sigma_a1*z1);
      y=mu_b1+(sigma_b1*((rho*z1)+(z2*sqrt(1-(rho**2)))));
      output;
    end;
  run;
  proc kde data=truenorm;
    bivar x y / out=truekde_both gridl=-3 gridu=3 ng=61;
  run;
   
  filename out ".";
  goptions reset=global device=png gsfname=out xmax=5.5 ymax=4.25;
    symbol1 color=red value=none width=2 interpol=spline;
    symbol2 color=green value=none width=2 interpol=spline;
    legend1 label=none position=(top right inside) mode=share value=("Transformed 1st PC" "True Standard Normal");
  
    axis1 order=(-3 to 3 by 0.5);
    axis2 order=(0 to &fmax. by &fstep.);
    title1 "Candidate Husband Data";
    title2 "Before Transformation";
    proc gplot data=kde0_a1;
      plot density*value
        /haxis=axis1 vaxis=axis2 name="density_PCa1";
    run;
    title2 "After Transformation";
    proc gplot data=kde1_a1;
      plot density*value density2*value 
        /overlay haxis=axis1 vaxis=axis2 name="density_tPCa1" legend=legend1;
    run;
    title1 "Candidate Wife Data";
    title2 "Before Transformation";
    proc gplot data=kde0_b1;
      plot density*value
        /haxis=axis1 vaxis=axis2 name="density_PCb1";
    run;
    title2 "After Transformation";
    proc gplot data=kde1_b1;
      plot density*value density2*value 
        /overlay haxis=axis1 vaxis=axis2 name="density_tPCb1" legend=legend1;
    run;

    axis1 order=(-3 to 3 by 0.5);
    axis2 order=(-3 to 3 by 0.5);
    axis3 order=(0 to &fmaxb. by &fstepb.);
    title1 "Bivariate Density of 1st PCs Between Spouses";
    title2 "Before Transformation";
    proc g3d data=kde0_both;
      plot value1*value2=density
        /xaxis=axis1 yaxis=axis2 zaxis=axis3 tilt=45 name="surface_PCa1_PCb1";
    run;
    title2 "After Transformation";
    proc g3d data=kde1_both;
      plot value1*value2=density
        /xaxis=axis1 yaxis=axis2 zaxis=axis3 tilt=45 name="surface_tPCa1_tPCb1";
    run;
    title1 "True Bivariate Normal Density";
    title2 "Matching Covariance Matrix";
    proc g3d data=truekde_both;
      plot value1*value2=density
        /xaxis=axis1 yaxis=axis2 zaxis=axis3 tilt=45 name="surface_bivar_norm";
    run;
  quit;

%mend;
%let implicate=1;
%let seed=0;
%input2royston;






