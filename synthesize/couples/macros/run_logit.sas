
%macro run_logit;
  libname metadata "metadata";
  data metadata.pid_m&m._mjob&mjob.;
    pid=&sysjobid.;
  run;

  %include "macros/fastbb.sas";
  %include "macros/logit_impute.sas";
  *include "macros/alt_transform_w.sas";
  %include "macros/transform_w.sas";
  %local mnobs nstrata i stratum;
  libname impwork "&impwork.";

  *** get count of observations in this cluster for imputation set;
  %let mnobs=0;
  data _null_;
    set impwork.mstrata&mjob._list&s. nobs=nobs;
    call symput("mnobs",compress(put(nobs,12.)));
    stop;
  run;
  *** get number of strata in this cluster;
  %let nstrata=0;
  data strata_size;
    set impwork.strata_size_list&s. end=lastobs;
    retain _count_ 0;
    if _cluster_=&mjob. then do;
      _count_=_count_+1;
      output;
    end;
    if lastobs then call symput("nstrata",compress(put(_count_,12.)));
  run;
  %do i=1 %to &nstrata.;
    %local fobs&i. fobs_m&i.;
    %let fobs&i.=0;
    %let fobs_m&i.=0;
  %end;
  %if &mnobs.>0 %then %do;
    *** get observation numbers for first obs of each stratum in both estimation and imputation sets;
    data _null_;
      set impwork.strata&mjob._list&s.;
      by _stratum_;
      retain _count_ 0;
      if first._stratum_ then do;
        _count_=_count_+1;
        call symput("fobs" || compress(put(_count_,12.)),compress(put(_n_,12.)));
      end;
    run;
    data impwork.mstrata&mjob._list&s. (drop=_count_);
      set impwork.mstrata&mjob._list&s.;
      by _stratum_;
      retain _count_ 0;
      tobs1=_n_;
      if first._stratum_ then do;
        _count_=_count_+1;
        call symput("fobs_m" || compress(put(_count_,12.)),compress(put(_n_,12.)));
      end;
    run;
    *** loop over strata in this cluster;
    %do i=1 %to &nstrata.;
      *** check to make sure nothing went wrong in assigning stratum pointers;
      %put FOBS&i.=&&fobs&i.. FOBS_M&i.=&&fobs_m&i..;
      %let check_fobs=0;
      %if &&fobs&i..=0 %then %do;
        %put ERROR: Stratum not found in estimation set;
        %let check_fobs=1;
      %end;
      %if &&fobs_m&i..=0 %then %do;
        %put ERROR: Stratum not found in imputation set;
        %let check_fobs=1;
      %end;
      %if &check_fobs.=1 %then %do;
        data _null_;
          abort abend;
        run;
      %end;
      *** put stratum number into a macro variable;
      data _null_;
        set strata_size (firstobs=&i.);
        call symput("stratum",compress(put(_stratum_,12.)));
        stop;
      run;
      *** prepare this imputation stratum for modifying the cluster after imputation;
      data mstratum (drop=tobs1);
        set impwork.mstrata&mjob._list&s. (firstobs=&&fobs_m&i..);
        tobs2=tobs1;
        if _stratum_=&stratum. then output;
        else stop;
      run;
      data stratum;
        set impwork.strata&mjob._list&s. (firstobs=&&fobs&i..);
        if _stratum_=&stratum. then output;
        else stop;
      run;
      data _null_;
        file PRINT;
        put "Set &s., Stratum &stratum.";
      run;
      %put *********** begin the impute *************;
      %put REGRESSORS: &regressors.;
      %logit_impute(stratum,mstratum,&curvar.,&regressors.,&transform_list.,
        interactions=&interaction_list.,seed=&seed.,minvar=&min_imp_var.,maxvar=&max_imp_var.,suffix=);
      %let seed=&outseed.;
      %put *********** end the impute ***************;
      proc freq data=stratum;
        tables &curvar. /missprint;
        title1 "Estimation Set: &curvar.";
      run;
      proc freq data=mstratum;
        tables &curvar. /missprint;
        title1 "Imputation Set: &curvar.";
      run;
      data mstratum;
        set mstratum (keep=_idobs_ &curvar. tobs2);
        _stratum_=&stratum.;
      run;
      *** modify the cluster with the newly imputed values;
      data impwork.mstrata&mjob._list&s.;
        set mstratum (rename=(&curvar.=imputed));
        modify impwork.mstrata&mjob._list&s. point=tobs2;
        if _error_=1 then do;
          put 'WARNING: occurred for TOBS=' tobs2 /
          'during DATA step iteration' _n_ /
          'TOBS value may be out of range.';
          _error_=0;
          stop;
        end;
        &curvar.=imputed;
      run;
      proc datasets lib=work nolist;
        %if %sysfunc(exist(stratum)) %then %do;
          delete stratum;
        %end; 
        %if %sysfunc(exist(mstratum)) %then %do;
          delete mstratum;
        %end; 
      run;
    %end; /* end of i-loop over strata */
    proc datasets lib=work nolist;
      %if %sysfunc(exist(strata_size)) %then %do;
        delete strata_size;
      %end; 
    run;
  %end; /* end of if-clause imputation file exists */

  /***
   If there was an error in this remote job setting OBS=0,
   then this next step will fail -- allowing us to test
   for such an error in the parent job.
  ***/
  data impwork.test4obs_set_to_zero_&mjob.;
    set impwork.test4obs_set_to_zero_&mjob. end=lastobs;
    output;
    if lastobs then do;
      i=2; output;
    end;
  run;
%mend;


