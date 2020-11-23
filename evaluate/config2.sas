
*** Variables to use in modeling marital link;
%let vars_moms=
hispanic foreign_born time_arrive_usa total_der_fica_2009 total_der_fica_2010
sipp_birthdate nonwhite black pos_der_fica_2009 pos_der_fica_2010
educ_d1 educ_d3 educ_d4 educ_d5
bd2 bd3 tau2 tdf2009_2
bd_tdf2009 bd_educ tdf2009_educ
;
%let vars_kids=
hispanic foreign_born time_arrive_usa total_der_fica_2009 total_der_fica_2010
sipp_birthdate nonwhite black pos_der_fica_2009 pos_der_fica_2010
educ_d1 educ_d3 educ_d4 educ_d5
bd2 bd3 tau2 tdf2009_2
bd_tdf2009 bd_educ tdf2009_educ
;
%let num_factors=18;

*** Variable that defines a unique respondent;
%let idvar=personid;

*** Stratification variable for linking;
%let byvar=rot;

*** Variable used to penalize distance function when too far apart (penalty_condition);
%let penalty_variable=adj_age;
%let penalty_condition=20;

*** Variable used to sort estimation and imputation;
%let sort_variable=bd_for_sort;

*** Variable used to limit number of linkages to one mother;
%let kid_limit=num_kids;

/***********************************************************************
 Macro to make variables in any of the above lists that are not already
 on the input data but are functions of variables on the input data.
***********************************************************************/
%macro make_vars;
  kid_recno=0;

  bd_for_sort=sipp_birthdate;

  if linked_mom=1 then adj_age=year(sipp_birthdate)+32;
  else if linked_child=1 then adj_age=year(sipp_birthdate);

  if race>1 then nonwhite=1; else nonwhite=0;
  if race=2 then black=1; else black=0;
  if educ_5cat=1 then educ_d1=1; else educ_d1=0;
  if educ_5cat=3 then educ_d3=1; else educ_d3=0;
  if educ_5cat=4 then educ_d4=1; else educ_d4=0;
  if educ_5cat=5 then educ_d5=1; else educ_d5=0;

  bd2=(sipp_birthdate/1000)**2;
  bd3=(sipp_birthdate/1000)**3;
  if foreign_born=1 then tau2=time_arrive_usa*2;
  else tau2=0;

  if pos_der_fica_2009=1 then tdf2009_2=(total_der_fica_2009/100000)**2;
  else tdf2009_2=0;

  bd_tdf2009=(sipp_birthdate/1000)*(sum(0,total_der_fica_2009)/100000);
  bd_educ=(sipp_birthdate/1000)*educ_5cat;
  tdf2009_educ=(sum(0,total_der_fica_2009)/100000)*educ_5cat;
%mend;

*** Turn structural zeros into real zeros for the sake of the modeling routine;
%macro add_zero;
  %local j jvar;
  %let j=1;
  %do %until("%scan(&vars_moms.,&j.)"="");
    %let jvar=%scan(&vars_moms.,&j.);
    &jvar.=sum(0,&jvar.);
    %let j=%eval(&j.+1);
  %end;
  %let j=1;
  %do %until("%scan(&vars_kids.,&j.)"="");
    %let jvar=%scan(&vars_kids.,&j.);
    &jvar.=sum(0,&jvar.);
    %let j=%eval(&j.+1);
  %end;
%mend;

