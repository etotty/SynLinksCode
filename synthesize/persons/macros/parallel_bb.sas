
%macro parallel_bb;

  %local s mjob end_signal bb_smallest;
  %let bb_smallest=10;
  %stratify(estimation_set&m.,imputation_set&m.,&bb_smallest.,absolute_smallest=3);

  *** Progress through lists of stratifiers from optimal list to coarsest list;
  %do s=1 %to &nlists.;
    /***
     If list &s. produced previously unaccounted strata that have
     enough non-missing sample to estimate the model, then proceed.
    ***/
    %if &&use_list&s..=1 %then %do;
      %let end_signal=0;
      %do mjob=1 %to &nprocs.;
        *** initialize a test for an error setting OBS equal to zero in remote job;
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
%syslput output_vars=&output_vars.;     
%syslput m=&m.;     
%syslput impwork=&impwork.;     
%syslput nprocs=&nprocs.;     
%syslput n=&n.;
%syslput mjob=&mjob.;     
%syslput s=&s.;     
%syslput seed=&seed.;     
%syslput nlists=&nlists.;     
%syslput stratifiers&s.=&&stratifiers&s..;     
RSUBMIT process=job&mjob. wait=no;
  proc printto log="&impwork./mpoutput_&mjob..log" new;
  proc printto print="&impwork./mpoutput_&mjob..lst" new;
  %nrstr(%%)include "macros/run_bb.sas";
  %nrstr(%%)run_bb;
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
  %end /* end of loop over sets */

  *** Now put it all back together;
  %macro allsets;
    %local s mjob exist;
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
  %if %allsets~= %then %do;
    data imputed (keep=_idobs_ &curvar. &output_vars.);
      set %allsets;
    run;	    
    proc sort data=imputed;
      by _idobs_;
    run;
    data imputation_set&m.;
      merge imputation_set&m. (in=aa drop=&curvar. &output_vars.) imputed (in=bb);
      by _idobs_;
      if aa & bb then output;
      else do;
        put "ERROR: imputed values did not match up with original imputation set.";
        abort abend;
      end;
    run;
    proc print data=imputation_set&m. (obs=50);
      var _idobs_ &curvar. &output_vars.;
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


