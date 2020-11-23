
%include "filelocations.sas";
%include "macros/fastbb.sas";
%include "macros/random_links_1to1.sas";
%include "macros/transform_w.sas";
%include "macros/extract_pc.sas";

%macro link_spouses;

  *** need to specify implicate before including config.sas;
  %include "config1.sas";

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
    temp1_a (keep=&idvar. &byvar. &vars_men. &penalty_variable. rename=(%add_prefix1(m_,&idvar. &vars_men.)))
    temp1_b (keep=&idvar. &byvar. &vars_women. &penalty_variable. rename=(%add_prefix1(f_,&idvar. &vars_women.)))
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
  data
    temp2_a (keep=&idvar. &byvar. &vars_men. &penalty_variable. rename=(%add_prefix1(m_,&idvar. &vars_men.)))
    temp2_b (keep=&idvar. &byvar. &vars_women. &penalty_variable. rename=(%add_prefix1(f_,&idvar. &vars_women.)));
    set estlib.&estfile. (where=(linked_couple=1));
    
    %make_vars;
    %add_zero;
    if male=1 then output temp2_a;
    else if male=0 then output temp2_b;
  run;
  %let ren_vars_men=%add_prefix2(m_,&vars_men.);
  %let ren_vars_women=%add_prefix2(f_,&vars_men.);

    data temp_both_a;
      set temp1_a (in=a1) temp2_a (in=a2);
      if a1 then _source=1;
      else _source=2;
    run;
    %extract_pc(temp1_a,temp_both_a,&ren_vars_men.,&num_factors.,basename=PCa,interact=0);
    data temp1_a (drop=_source) temp2_a (drop=_source);
      set temp_both_a;
      if _source=1 then output temp1_a;
      else output temp2_a;
    run;
    data temp_both_b;
      set temp1_b (in=b1) temp2_b (in=b2);
      if b1 then _source=1;
      else _source=2;
    run;
    %extract_pc(temp1_b,temp_both_b,&ren_vars_women.,&num_factors.,basename=PCb,interact=0);
    data temp1_b (drop=_source) temp2_b (drop=_source);
      set temp_both_b;
      if _source=1 then output temp1_b;
      else output temp2_b;
    run;

    %let new_vars_men=;
    %let new_vars_women=;
    %do j=1 %to &num_factors.;
      %let new_vars_men=&new_vars_men. PCa&j.;
      %tfile(PCa&j.,temp1_a,tmale&j.);
      %transform(PCa&j.,temp1_a,tmale&j.);
      %transform(PCa&j.,temp2_a,tmale&j.);
      %let new_vars_women=&new_vars_women. PCb&j.;
      %tfile(PCb&j.,temp1_b,tfemale&j.);
      %transform(PCb&j.,temp1_b,tfemale&j.);
      %transform(PCb&j.,temp2_b,tfemale&j.);
    %end;

    %let idvar_men=m_&idvar.;
    %let idvar_women=f_&idvar.;
    %random_links(
      temp1_a, temp1_b, temp1_xwalk,
      temp2_a, temp2_b, temp2_xwalk_imp,
      &idvar_men., &idvar_women., &new_vars_men., &new_vars_women.,
      0, penalty_var=&penalty_variable., penalty_cond=&penalty_condition., seed=&seed., bygroup=&byvar.);

  data outlib.syn0_spouse_xwalk&implicate.;
    set temp2_xwalk_imp;
  run;
  proc means data=outlib.syn0_spouse_xwalk&implicate.;
    var distance;
  run;
  data temp;
    set outlib.syn0_spouse_xwalk&implicate. nobs=nobs;
    order_cat=ceil(100*order/nobs);
  run;
  proc means data=temp;
    var distance;
    class order_cat;
    types order_cat;
  run;

  data _origdist_;
    set _origdist_;
    if distfrommean=. then distfrommean_cat=.;
    else if distfrommean<5 then distfrommean_cat=5;
    else if distfrommean<10 then distfrommean_cat=10;
    else if distfrommean<25 then distfrommean_cat=25;
    else if distfrommean<50 then distfrommean_cat=50;
    else if distfrommean<100 then distfrommean_cat=100;
    else if distfrommean<250 then distfrommean_cat=250;
    else if distfrommean<500 then distfrommean_cat=500;
    else if distfrommean<1000 then distfrommean_cat=1000;
    else distfrommean_cat=1001;
  run;
  proc freq data=_origdist_ noprint;
    tables distfrommean_cat /out=freq1;
  run;
  data temp2_xwalk_imp;
    set temp2_xwalk_imp;
    if distfrommean=. then distfrommean_cat=.;
    else if distfrommean<5 then distfrommean_cat=5;
    else if distfrommean<10 then distfrommean_cat=10;
    else if distfrommean<25 then distfrommean_cat=25;
    else if distfrommean<50 then distfrommean_cat=50;
    else if distfrommean<100 then distfrommean_cat=100;
    else if distfrommean<250 then distfrommean_cat=250;
    else if distfrommean<500 then distfrommean_cat=500;
    else if distfrommean<1000 then distfrommean_cat=1000;
    else distfrommean_cat=1001;
  run;
  proc freq data=temp2_xwalk_imp noprint;
    tables distfrommean_cat /out=freq2;
  run;
  data freqs;
    merge freq1 (in=aa keep=distfrommean_cat percent rename=(percent=percent1)) freq2 (in=bb keep=distfrommean_cat percent rename=(percent=percent2));
    by distfrommean_cat;
    if aa or bb;
  run;
  proc print;


%mend;
%let implicate=1;
%let seed=0;
%link_spouses;
%let implicate=2;
%let seed=0;
%link_spouses;
%let implicate=3;
%let seed=0;
%link_spouses;
%let implicate=4;
%let seed=0;
%link_spouses;






