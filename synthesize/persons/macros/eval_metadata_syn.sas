
%macro evaluate_metadata;
  %local nobs;
  %let nobs=0;

  filename report "report.lst";
  data _null_;
    file report;
    put "REPORT ON CURRENT MODEL SPECIFICATIONS";
    put " ";
  run;

  /*************************************
   Get the list of variables actually on
   the input file to compare to list of
   variables specified in the modeling
   specifications from the vardefs_*.sas
   files.
  *************************************/
  proc contents data=inlib.&infilename. out=incontents (keep=name nobs type) noprint;
  data incontents (keep=check_name sasvartype);
    length check_name $32.;
    set incontents;
    sasvartype=type;
    %standardize_varname(name,check_name,0);
    call symput("nobs",compress(put(nobs,12.)));
  run;
  proc sort data=incontents;
    by check_name;
  run;

  /*************************************
   Now we check to see if every variable
   from vardefs that is claimed to be
   on the input file is in fact on the 
   input file.

   First check variables being modeled:
  *************************************/
  data modeled_vars;
    set metadata.master_variable_list (where=(source=1));
    check_name=varname;
    check_type=0;
  run;
  proc sort data=all_vars_referenced (where=(check_type in (3,6))) out=temp_listed;
    by varname;
  run;
  proc sort data=modeled_vars;
    by varname;
  run;
  data temp_listed;
    merge modeled_vars (in=aa drop=check_:) temp_listed (in=bb);
    by varname;
    if aa & bb;
  run;
  data modeled_vars;
    set modeled_vars temp_listed;
  run;
  proc sort data=modeled_vars;
    by check_name;
  run;
  data modeled_vars;
    merge modeled_vars (in=aa) incontents (in=bb);
    by check_name;
    if aa;
    file report mod;
    if bb then do;
      *** the variable specified for modeling in vardefs was found in &infilename.;
      output;
    end;
    else do;
      if check_type=0 then put "WARNING: " check_name
        " was specified to be synthesized in its vardefs, but was not found on &infilename.";
      else if check_type=3 then put "WARNING: " check_name " was specified to be calculated at the same time as "
        varname " in the vardefs for " varname ", but was not found on &infilename.";
      else if check_type=6 then put "WARNING: " check_name " was specified as an additional imputation output with "
        varname " in the vardefs for " varname ", but was not found on &infilename.";
      if check_type in (0,3,6) then put " ";
    end;
  run;
  
  /*************************************
   Next check variables that are not 
   modeled nor being calculated for modeling
   purposes, but are referenced in vardefs
   files as predictors or inputs:
  *************************************/
  data temp_nocheck;
    set metadata.master_variable_list;
    check_name=varname;
    check_type=0;
  run;
  proc sort data=all_vars_referenced (where=(check_type in (3,6))) out=temp_listed;
    by varname;
  run;
  proc sort data=temp_nocheck;
    by varname;
  run;
  data temp_listed;
    merge temp_nocheck (in=aa drop=check_:) temp_listed (in=bb);
    by varname;
    if aa & bb;
  run;
  data temp_nocheck;
    set temp_nocheck temp_listed;
  run;
  proc sort data=temp_nocheck;
    by check_name;
  run;
  proc sort data=all_vars_referenced;
    by check_name;
  run;
  data other_vars;
    merge all_vars_referenced (in=aa) temp_nocheck (in=bb keep=check_name);
    by check_name;
    if aa;
    if bb then do;
      /****************************************
      these variables have already been checked
      or are not expected to be on &infilename.
      so we do not check for them
      ****************************************/
    end;
    else do;
      output;
    end;
  run;
  data other_vars;
    merge other_vars (in=aa) incontents (in=bb);
    by check_name;
    if aa;
    file report mod;
    if bb then do;
      *** the variable specified as a predictor in vardefs was found in &infilename.;
      output;
    end;
    else do;
      if check_name ne "_constant_" and check_type ~in (7,8) then do;
        put "WARNING: " check_name
          "was specified as a predictor/input in vardefs for " varname + (-1)
          ", but was neither found on &infilename, nor was specified"
          " to be calculated for modeling purposes in any other vardefs.";
        put " ";
      end;
    end;
  run;
  
  /*************************************
   Next check that variables specified
   to be calculated for modeling purposes
   and not on &infilename. are indeed
   not on &infilename.
  *************************************/
  data temporary_vars;
    set metadata.master_variable_list (where=(source=0));
    check_name=varname;
    check_type=0;
  run;
  proc sort data=all_vars_referenced (where=(check_type=3)) out=temp_listed;
    by varname;
  run;
  proc sort data=temporary_vars;
    by varname;
  run;
  data temp_listed;
    merge temporary_vars (in=aa drop=check_:) temp_listed (in=bb);
    by varname;
    if aa & bb;
  run;
  data temporary_vars;
    set temporary_vars temp_listed;
  run;
  proc sort data=temporary_vars;
    by check_name;
  run;
  data temporary_vars;
    merge temporary_vars (in=aa) incontents (in=bb);
    by check_name;
    if aa;
    file report mod;
    if bb then do;
      put "WARNING: " check_name
        " was specified in vardefs to be calculated"
        " for temporary modeling purposes,"
        " but already exists on &infilename.";
      put " ";
    end;
  run;

  /*************************************
   Check logical consistency of variables
   specified to be calculated in vardefs
  *************************************/
  proc sort data=calc_io_pairs;
    by outvar invar;
  run;
  proc sort data=calc_io_pairs out=inverse_pairs (rename=(outvar=new_invar invar=new_outvar));
    by invar outvar;
  run;
  data _null_;
    merge calc_io_pairs (in=aa) inverse_pairs (in=bb rename=(new_invar=invar new_outvar=outvar));
    by outvar invar;
    file report mod;
    if aa and bb then do;
      put "WARNING: in vardefs, " invar "was specified as an input/universe-determinant for "
        outvar + (-1) ", and " outvar "was specified as an input/universe-determinant for " invar + (-1) ".";
      put " ";
    end;
  run;

  /*************************************
   Now print summary stats on of every
   variable set for synthesis.
  *************************************/
  %include "metadata/select_universe.sas";
  %local tmp1 tmp2 sasvartype;
  %let i=1; %let istop=0;
  %do %until(&istop.=1);
    %let tmp1=;
    %let tmp2=;
    %let sasvartype=;
    data _null_;
      set modeled_vars (firstobs=&i.) end=lastobs;
      call symput("tmp1",compress(check_name));
      call symput("tmp2",compress(varname));
      call symput("sasvartype",compress(sasvartype));
      if lastobs then call symput("istop","1");
      stop;
    run;
    %if "&tmp1."~="" %then %do;
      %if &sasvartype.=1 %then %do;
        proc means data=inlib.&infilename. (where=((%select_universe(&tmp2.)))) noprint;
          var &tmp1.;
          output out=temp_means
            n(&tmp1.)=n nmiss(&tmp1.)=nmiss mean(&tmp1.)=mean std(&tmp1.)=std
            min(&tmp1.)=min q1(&tmp1.)=q1 median(&tmp1.)=median
            q3(&tmp1.)=q3 max(&tmp1.)=max;
        run;
        data temp_means;
          length check_name $32.;
          set temp_means (keep=n nmiss mean std min q1 median q3 max);
          check_name=compress("&tmp1.");
        run;
      %end;
      %else %do;
        data temp_means;
          check_name=compress("&tmp1.");
          n=&nobs.; nmiss=.; mean=.; std=.; min=.; q1=.; median=.; q3=.; max=.;
          output;
        run;
      %end;
      data summary_stats;
        set %if &i.>1 %then %do; summary_stats %end; temp_means;
      run;
    %end;
    %else %let istop=1;
    %let i=%eval(&i.+1);
  %end;
  proc sort data=summary_stats;
    by check_name;
  run;
  proc sort data=modeled_vars;
    by check_name;
  run;
  data summary_stats;
    merge modeled_vars (in=aa keep=check_name) summary_stats;
    by check_name;
    if aa;
    if n=. and nmiss=. then nmiss=&nobs.;
  run;
  data metadata.all_imputation_vars;
    set modeled_vars;
  run;
  data metadata.all_vars_referenced;
    set all_vars_referenced;
  run;
%mend;


