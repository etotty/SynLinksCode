
%include "filelocations.sas";
%include "macros/fastbb.sas";
%include "macros/random_links_1toN.sas";
%include "macros/transform_w.sas";
%include "macros/extract_pc.sas";


%macro link_kids;

  *** need to specify implicate before including config.sas;
  %include "config2.sas";

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
    temp1_a (keep=&idvar. &vars_moms. &penalty_variable. &kid_limit. rename=(%add_prefix1(m_,&idvar. &vars_moms.)))
    temp1_b (keep=&idvar. &vars_kids. &penalty_variable. &sort_variable. rename=(%add_prefix1(k_,&idvar. &vars_kids.)))
    temp1_xwalk (keep=&idvar. mom_&idvar. rename=(&idvar.=k_&idvar. mom_&idvar.=m_&idvar.));
    set estlib.&estfile. (where=(linked_mom=1 or linked_child=1));
    %make_vars;
    %add_zero;
    if linked_mom=1 then output temp1_a;
    else if linked_child=1 then do;
      output temp1_b;
      output temp1_xwalk;
    end;
  run;
  data
    temp2_a (keep=&idvar. &vars_moms. &penalty_variable. &kid_limit. rename=(%add_prefix1(m_,&idvar. &vars_moms.)))
    temp2_b (keep=&idvar. &vars_kids. &penalty_variable. rename=(%add_prefix1(k_,&idvar. &vars_kids.)));
    set implib.&impfile.&implicate. (where=(linked_mom=1 or linked_child=1));
    %make_vars;
    %add_zero;
    if linked_mom=1 then output temp2_a;
    else if linked_child=1 then output temp2_b;
  run;
  %let ren_vars_moms=%add_prefix2(m_,&vars_moms.);
  %let ren_vars_kids=%add_prefix2(k_,&vars_kids.);

    data temp_both_a;
      set temp1_a (in=a1) temp2_a (in=a2);
      if a1 then _source=1;
      else _source=2;
    run;
    %extract_pc(temp1_a,temp_both_a,&ren_vars_moms.,&num_factors.,basename=PCa,interact=0);
    %let nf_moms=&final_k.;
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
    %extract_pc(temp1_b,temp_both_b,&ren_vars_kids.,&num_factors.,basename=PCb,interact=0);
    %let nf_kids=&final_k.;
    data temp1_b (drop=_source) temp2_b (drop=_source);
      set temp_both_b;
      if _source=1 then output temp1_b;
      else output temp2_b;
    run;

    %let new_vars_moms=;
    %do j=1 %to &nf_moms.;
      %let new_vars_moms=&new_vars_moms. PCa&j.;
      %tfile(PCa&j.,temp1_a,tmoms&j.);
      %transform(PCa&j.,temp1_a,tmoms&j.);
      %transform(PCa&j.,temp2_a,tmoms&j.);
    %end;
    %let new_vars_kids=;
    %do j=1 %to &nf_kids.;
      %let new_vars_kids=&new_vars_kids. PCb&j.;
      %tfile(PCb&j.,temp1_b,tkids&j.);
      %transform(PCb&j.,temp1_b,tkids&j.);
      %transform(PCb&j.,temp2_b,tkids&j.);
    %end;

    %let idvar_moms=m_&idvar.;
    %let idvar_kids=k_&idvar.;
    %random_links(
      temp1_a, temp1_b, temp1_xwalk,
      temp2_a, temp2_b, temp2_xwalk_imp,
      &idvar_moms., &idvar_kids., &new_vars_moms., &new_vars_kids., &kid_limit.,
      0, bsortvar=&sort_variable., penalty_var=&penalty_variable., penalty_cond=&penalty_condition., seed=&seed., bygroup=);

  proc sort data=temp2_xwalk_imp;
    by &idvar_moms. &idvar_kids.;
  run;
  data outlib.syn_momchild_xwalk&implicate.;
    set temp2_xwalk_imp;
  run;
  proc means data=outlib.syn_momchild_xwalk&implicate.;
    var distance;
  run;
  proc print data=outlib.syn_momchild_xwalk&implicate. (obs=40);

  
/*
  proc sort data=temp2_xwalk_imp;
    by &idvar_kids.;
  run;
  proc sort data=temp2_b;
    by &idvar_kids.;
  run;
  data temp2_xwalk_imp;
    merge temp2_xwalk_imp (in=aa) temp2_b (keep=&idvar_kids. &penalty_variable. rename=(&penalty_variable.=kyear));
    by &idvar_kids.;
    if aa;
  run;
  proc sort data=temp2_xwalk_imp;
    by &idvar_moms.;
  run;
  proc sort data=temp2_a;
    by &idvar_moms.;
  run;
  data junk;
    set temp2_a;
    by &idvar_moms.;
    if last.&idvar_moms. then do;
      &penalty_variable.=&penalty_variable.-32;
      output;
    end;
  run;
  data temp2_xwalk_imp;
    merge temp2_xwalk_imp (in=aa) junk (keep=&idvar_moms. &penalty_variable. rename=(&penalty_variable.=myear));
    by &idvar_moms.;
    if aa;
    diff=kyear-myear;
  run;
  proc means data=temp2_xwalk_imp;
    var diff;
  run;
  proc print data=temp2_xwalk_imp (obs=40);
    var &idvar_moms. &idvar_kids. myear kyear;  
  run;
*/

%mend;

%let implicate=1;
%let seed=0;
%link_kids;
%let implicate=2;
%let seed=0;
%link_kids;
%let implicate=3;
%let seed=0;
%link_kids;
%let implicate=4;
%let seed=0;
%link_kids;








