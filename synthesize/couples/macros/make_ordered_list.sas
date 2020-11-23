
%macro make_ordered_list;

  /*************************************
   Using information from vardefs about
   inputs to calculated variables and
   variable used to determine universe
   of other variables, determine a 
   ranking (generation) of the variables
   in the imputation list to respect
   the logic of these deterministic
   dependencies. 1st generation variables
   do not depend on any other variables.
   2nd generation variables depend on
   at least one 1st generation variable.
   etc.
  *************************************/
  *** initialize all variables at 0;
  proc sort data=calc_io_pairs;
    by outvar;
  run;
  data generations (keep=invar outvar generation);
    set calc_io_pairs (keep=outvar);
    by outvar;
    if last.outvar then do;
      invar=outvar;
      generation=0;
      output;
    end;
  run;
  %local stopflag i;
  %let stopflag=1; %let i=1;
  data calc_io_pairs (index=(old_invar));
    set calc_io_pairs;
    old_invar=outvar;
    call symput("stopflag","0");
  run;
  *** loop until no more inputs are found;
  %do %until(&stopflag.=1);
    proc sort data=generations;
      by invar;
    run;
    *** merge on inputs to inputs (if any);
    data generations (keep=invar outvar generation);
      set generations (rename=(invar=old_invar)) end=lastobs;
      by old_invar;
      retain _stop_ 1;
      _found_=0;
      _original_=generation;
      _cont1_=0; _cont2_=0;
      do while(_cont1_=0);
        set calc_io_pairs (keep=invar old_invar) key=old_invar;
        if _cont2_=1 then _cont1_=1;
        if _iorc_=0 then do;
          _stop_=0;
          _found_=1;
          generation=_original_+1;
          output;
        end;
        else do;
          _error_=0;
          old_invar="_ZZZZZZZZ_";
          _cont2_=1;
        end;
      end;
      if _found_=0 then do;
        invar="";
        output;
      end;
      if lastobs then call symput("stopflag",compress(put(_stop_,4.)));
    run;
    *** re-sort and remove redundant pairs;
    proc sort data=generations;
      by outvar invar generation;
    run;
    data generations;
      set generations;
      by outvar invar;
      if outvar=invar then put "WARNING: Circular logic found for " outvar;
      if last.invar then output;
    run;
    %let i=%eval(&i.+1);
    *** stop if more than 1000000 iterations -- maybe something went wrong or was mis-specified;
    %if &i.>1000000 %then %let stopflag=1;
  %end;
  *** now that generation has been calculated, merge onto permanent metadata files;
  proc sort data=generations (keep=outvar generation);
    by outvar;
  run;
  data generations (keep=check_name generation);
    length check_name $32.;
    set generations;
    by outvar;
    retain max_generation;
    if first.outvar then max_generation=generation;
    max_generation=max(generation,max_generation);
    if last.outvar then do;
      generation=max_generation;
      check_name=outvar;
      output;
    end;
  run;
  proc sort data=metadata.all_imputation_vars;
    by check_name;
  run;
  data metadata.all_imputation_vars;
    merge metadata.all_imputation_vars (in=aa) generations (in=bb);
    by check_name;
    if aa;
    if ~bb then generation=0;
  run;
  proc sort data=metadata.all_imputation_vars;
    by varname check_type check_name;
  run;
  data tmp_generations (keep=varname max_generation rename=(max_generation=generation));
    set metadata.all_imputation_vars;
    by varname;
    retain max_generation;
    if first.varname then max_generation=0;
    max_generation=max(generation,max_generation);
    if last.varname then output;
  run;
  proc sort data=metadata.master_variable_list;
    by varname;
  run;
  data metadata.master_variable_list;
    merge metadata.master_variable_list (in=aa) tmp_generations;
    by varname;
    if aa;
  run;


  /*************************************
   Now sort the master variable list
   (which contains the imputation list
   where source=1) by source, generation,
   and level.
   Report any instances where analyst has 
   specified an imputation order (using
   the macro variable, level, from vardefs)
   that contradicts the logical order
   necessary for the deterministic
   relationships specified in vardefs.
  *************************************/
  proc sort data=metadata.master_variable_list;
    by source level generation;
  run;
  data _null_;
    set metadata.master_variable_list (where=(source>0)) end=lastobs;
    retain lag_gen;
    file PRINT;
    if _n_=1 then do;
      put "_______________________________________________________________________________________________________";
      put " ";
      put " ";
    end;
    if generation<lag_gen then do;
      put "WARNING: the vardef file for " varname "has specified an imputation order (with the level macro variable) "
        "that puts " varname "after a variable with a longer dependency tree. "
        "Review the order to make sure this is OK.";
      put " ";
      put " ";
    end;
    lag_gen=generation;
    if lastobs then do;
      put "_______________________________________________________________________________________________________";
    end;
  run;

  proc sort data=summary_stats (where=(n>0)) out=temp;
    by check_name;
  run;
  proc sort data=metadata.master_variable_list;
    by varname;
  run;
  data metadata.master_variable_list;
    merge metadata.master_variable_list (in=aa) temp (in=bb keep=check_name rename=(check_name=varname));
    by varname;
    if (aa & bb) or (aa & source=0) then output;
  run;
  proc sort data=metadata.master_variable_list;
    by source level generation;
  run;
  proc print data=metadata.master_variable_list;
    title "Print of the master variable list. Imputation list is where source=1.";
  run;
  proc print data=summary_stats;
    var check_name n nmiss mean std min q1 median q3 max;
    title "Some summary statistics of variables being imputed (directly or indirectly).";
  run;

%mend;


