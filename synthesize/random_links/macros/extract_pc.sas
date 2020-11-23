/*****************************************************
by Evan Totty

This program extracts the first k principal components 
	from the internal set of variables, aka estimation
	set ("est_set"). 

The factor/component scoring coefficients for each component 
	(i.e., the coefficients that show how the component loads 
	on each variable) are then saved and used to generate 
	principal components of the synthetic variables.

Finally, the k synthetic principal components are fully interacted 
	with each other. 

Inputs: 
	1) estimation set, "est_set" (candidate set of internal 
		variables on which principal components are 
		estimated)
	2) imputation set, "imp_set" (set of synthetic variables, 
		which are used to generate synthetic principal 
		components)
	3) number of principal components to extract, "k"
	4) whether to interact the synthetic components, "interact" 
		(set equal to "1" for interactions, "0" otherwise)

	*** "est_set" and "imp_set" are Nxp matrices, where N is 
		the number of records/individuals and p is the 
		number of variables.
	
Outputs:
	1) "imp_set" is edited to contain the k principal components
		and their interactions (if requested)
        2) final_k = global macro variable specifying final number of factors
*****************************************************/


%macro extract_pc(est_set,imp_set,invars,k,basename=PC,interact=1,suffix=);

%local est_set imp_set invars k basename interact i j suffix;
%global final_k;
%let final_k=0;

/* 1. Extract the first k principal components. Save components and coefficients. */
proc factor data=&est_set. (keep=&invars.)
  simple
  method=prin
  nfactors=&k.
  score
  outstat=Coef&suffix. noprint;
run;
%local new_k; %let new_k=0;
data _null_;
  set Coef&suffix. (keep=_name_ _type_ where=(_type_="SCORE"));
  call symput("new_k",compress(put(_n_,12.)));
run;
%if &new_k.<&k. %then %do;
  %put Number of factors reduced from &k. to &new_k.;
  %let k=&new_k.;
%end;
%let final_k=&k.;

%if &k.>0 %then %do;
  /* 2. From results on estimation set create principal components on imputation set */
  proc score data=&imp_set.
    score=Coef&suffix.
    out=synth_pc&suffix.;
  run;

  data &imp_set.;
    set synth_pc&suffix. (drop=&invars. rename=Factor1-Factor&k.=&basename.1-&basename.&k.);
  run;

  /* 3. Fully interact all of the variables */
  %if &interact.=1 %then %do;
    data &imp_set.;
      set &imp_set.;
      %do i=1 %to &k.;
        %do j=&i %to &k.;
          &basename.&i._&j.=&basename.&i.*&basename.&j.;
        %end;
      %end;
    run;		
  %end;
%end;

proc datasets lib=work;
  delete Coef&suffix.;
  %if %sysfunc(exist(synth_pc&suffix.)) %then %do;
    delete synth_pc&suffix.;
  %end;
run;

%mend extract_pc;


