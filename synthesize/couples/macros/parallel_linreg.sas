
%macro parallel_linreg;

  %local s mjob end_signal transform_depvar;
  %stratify(estimation_set&m.,imputation_set&m.,&smallest_regstrat.);
  data _null_;
    set metadata.master_variable_list (where=(varname="&curvar."));
    call symput("transform_depvar",put(transform,z1.));
  run;
  *** Progress through lists of stratifiers from optimal list to coarsest list;
  %do s=1 %to &nlists.;
    /***
     If list &s. produced previously unaccounted strata that have
     enough non-missing sample to estimate the model, then proceed.
    ***/
    %if &&use_list&s..=1 %then %do;
      %let end_signal=0;
      /***
       Perform imputation on similarly sized clusters of strata
       (as defined by the current list of stratifiers)
       in parallel remote jobs.
      ***/
      %do mjob=1 %to &nprocs.;
        *** initialize a test for an error setting OBS=0 in remote job;
        data test4obs_set_to_zero_&mjob.;
          i=1; output;
        run;
        *** initialize seed for each remote job;
        data _null_;
          seed=&seed.;
          call ranuni(seed,x1);
          call ranuni(seed,x2);
          call ranuni(seed,x3);
          a1=min(of x1-x3);
          a2=median(of x1-x3);
          a3=max(of x1-x3);
          new_seed=ceil((a2-a1)*2147483646/(a3-a1));
          call symput("seed",compress(put(new_seed,12.)));
        run;
***************************************;
********** LAUNCH REMOTE JOB **********;
***************************************;
options sascmd="sas";
SIGNON job&mjob.;
%syslput curvar=&curvar.;     
%syslput m=&m.;     
%syslput impwork=&impwork.;     
%syslput nprocs=&nprocs.;     
%syslput n=&n.;
%syslput mjob=&mjob.;     
%syslput s=&s.;     
%syslput seed=&seed.;     
%syslput nlists=&nlists.;     
%syslput transform_depvar=&transform_depvar.;     
%syslput regressors=&regressors.;     
%syslput transform_list=&transform_list.;     
%syslput interaction_list=&interaction_list.;     
%syslput stratifiers&s.=&&stratifiers&s..;     
%syslput min_imp_var=&min_imp_var.;     
%syslput max_imp_var=&max_imp_var.;     
RSUBMIT process=job&mjob. wait=no;
  proc printto log="&impwork./mpoutput_&mjob..log" new;
  proc printto print="&impwork./mpoutput_&mjob..lst" new;
  %nrstr(%%)include "macros/run_linreg.sas";
  %nrstr(%%)run_linreg;
ENDRSUBMIT;
***************************************;
***************************************;
***************************************;
      %end; /* end of loop over mjob */
      WAITFOR _ALL_ 
      %do mjob=1 %to &nprocs.;
        job&mjob.
      %end;
      ;
      %do mjob=1 %to &nprocs.;
        RGET job&mjob.; 
        SIGNOFF job&mjob.;
      %end;
      proc datasets lib=metadata nolist;
        %do mjob=1 %to &nprocs.;
          %if %sysfunc(exist(metadata.pid_m&m._mjob&mjob.)) %then %do;
            delete pid_m&m._mjob&mjob.;
          %end;
        %end;
      run;
      %do mjob=1 %to &nprocs.;
        *** check to see if each remote job ran without an error setting OBS=0;
        %let testnobs=0;
        data _null_;
          set test4obs_set_to_zero_&mjob. nobs=nobs;
          call symput("testnobs",compress(put(nobs,12.)));
          stop;
        run;
        %if &testnobs.<2 %then %let end_signal=1;
        *** append remote LOG and LST files to current LOG and LST file;
        data _null_;
          infile "&impwork./mpoutput_&mjob..log" truncover end=lastrecord;
          file LOG;
          input;
          put _infile_;
          if lastrecord then do;
            put " ";
            put "_";
          end;
        run;
        data _null_;
          infile "&impwork./mpoutput_&mjob..lst" truncover end=lastrecord;
          file PRINT;
          input;
          put _infile_;
          if lastrecord then do;
            put " ";
            put "_";
          end;
        run;
      %end;
      %if &end_signal.=1 %then %do;
        *** if there was an error setting OBS=0 in a remote job, then abort SRMI;
        data _null_;
          abort abend;
        run;
      %end;
    %end; /* end of if set is to be used */
  %end; /* end of loop over sets */

  *** Now put it all back together;
  %macro allsets;
    %local s mjob;
    %do s=1 %to &nlists.;
      %if &&use_list&s..=1 %then %do;
        %do mjob=1 %to &nprocs.;
          %if %sysfunc(exist(mstrata&mjob._list&s.)) %then %do;
            mstrata&mjob._list&s.
          %end;
        %end;
      %end;
    %end;
  %mend allsets;
  %put OKAY: %allsets;
  %if %allsets~= %then %do;
    data imputed (keep=_idobs_ &curvar.);
      set %allsets;
    run;	    
    proc sort data=imputed;
      by _idobs_;
    run;
    data imputation_set&m.;
      merge imputation_set&m. (in=aa drop=&curvar.) imputed (in=bb);
      by _idobs_;
      if aa & bb then output;
      else do;
        put "ERROR: imputed values did not match up with original imputation set.";
        abort abend;
      end;
    run;
    proc print data=imputation_set&m. (obs=50);
      var _idobs_ &curvar. &min_imp_var. &max_imp_var.;
      title1 "First 50 imputed observations for variable=&curvar. in implicate=&m.";
    run;
  %end;
  %else %do;
    %put ERROR: No imputations were performed for variable=&curvar. in implicate=&m.;
    data _null_;
      abort abend;
    run;
  %end;

  *** shuffle seed for next variable in SRMI;
  %global outseed;
  data _null_;
    seed=&seed.;
    call ranuni(seed,x1);
    call ranuni(seed,x2);
    call ranuni(seed,x3);
    a1=min(of x1-x3);
    a2=median(of x1-x3);
    a3=max(of x1-x3);
    new_seed=ceil((a2-a1)*2147483646/(a3-a1));
    call symput("outseed",compress(put(new_seed,12.)));
  run;

%mend;


