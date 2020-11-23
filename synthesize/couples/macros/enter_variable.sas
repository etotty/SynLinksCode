
%macro blank_macros;
  %local i;
  %global variable level ever_out_of_universe universe_determinants transform_depvar num_lists
     minimum_variable maximum_variable inputs regressors_notransform regressors_transform 
     interactions drop_vars outputs;
  *** Blank out all possible VARDEFS macros and macro variables;
  %let variable=;
  %let level=;
  %let ever_out_of_universe=;
  %let universe_determinants=;
  %macro universe_condition; %mend;
  %let transform_depvar=;
  %let num_lists=;
  %do i=1 %to 100;
    %global stratifiers&i.;
    %let stratifiers&i.=;
  %end;
  %let minimum_variable=;
  %let maximum_variable=;
  %let inputs=;
  %macro calculate_constraints; %mend;
  %let regressors_notransform=;
  %let regressors_transform=;
  %let interactions=;
  %macro post_impute; %mend;
  %let drop_vars=;
  %let outputs=;
  %let pi_outputs=;
  %macro calculate_variable; %mend;
%mend;


%macro enter_variable(model_method);
  %local i j tmp tmp2 model_method;
  *** &numvars. should already be defined from prog01_build_metadata.sas;
  %let numvars=%eval(&numvars.+1);
  %if "&variable."="" %then %do;
    %put Now entering metadata for %scan(&outputs.,1);
  %end;
  %else %do;
    %put Now entering metadata for &variable.;
  %end;

  /*************************************
   Build variable lists;

   This section expects the model specific subsets of
   the following items to already be defined:
     from VARDEFS_&variable..sas:
       &variable.
       &level.
       &ever_out_of_universe.
       &universe_determinants.
       &transform_depvar.
       &inputs.
       &outputs.
       &minimum_variable.
       &maximum_variable.
       &regressors_notransform.
       &regressors_transform.
       &num_lists.
       &stratifiers1.
       ...
       &&stratifiers&num_lists..
     from prog01_build_metadata.sas:
       metadata (libref)
       &workdir.
  *************************************/
  data
    new_variable (keep=varname model source level transform)
    /**********************************
      model
        =. if varname is being calculated as a function of other variables
        =1 if varname is being modeled with Bayes' bootstrap
        =2 if varname is being modeled with logistic regression
        =3 if varname is being modeled with linear regression
      source
        =0 if varname is not on input file and is calculated from
           other variables for modeling purposes
        =1 if varname is on the input file
      transform
        =0 if varname is being modeled as is with a linear regression
        =1 if varname is being modeled with a linear regression after transormation
    **********************************/
    new_io_pairs (keep=invar outvar)
    new_vars_referenced (keep=varname check_name check_type check_list check_transform)
    /**********************************
      check_type
        =1 if check_name is a variable used to determine when varname is in universe or used to calculate constraints
        =2 if check_name is an input for a calculated variable
        =3 if check_name is a variable being calculated temporarily for modeling purposes
        =4 if check_name is a stratifier for modeling varname
        =5 if check_name is a regressor for modeling varname
        =6 if check_name is an additional output other than varname being imputed at the same time as varname
        =7 if check_name is a variable specifying a minimum possible imputation for varname
        =8 if check_name is a variable specifying a maximum possible imputation for varname
      check_transform
        =0 if check_name is a regressor that should be used as is
        =1 if check_name is a regressor that should be transformed prior to estimation/imputation
    **********************************/
    interactions (keep=varname interaction_term)
    ;
    length varname $32.;
    length interaction_term $200.;
    length invar outvar $32.;
    length check_name $32.;
    *** Enumerate modeling method according to comments above;
    model=&model_method.;
    *** Is the variable on the input file, or to be made temporarily for modeling purposes?;
    if model=. then source=0;
    else do;
      source=1;
      %standardize_varname(&variable.,varname,1);
      call symput("variable",compress(varname));
    end;

    *** Store any SRMI ordering preferences here;
    if model=. then level=.;
    else do;
      %if "&level."~="" %then %do;
        level=&level.;
      %end;
      %else %do;
        level=0;
      %end;
    end;

    *** Store dependent variable transformation indicator;
    if model in (3) then do;
      %if "&transform_depvar."="" %then %do;
        transform=.;
      %end;
      %else %do;
        transform=&transform_depvar.;
      %end;
      if transform ~in (0,1) then put "ERROR: Invalid specification for dependent variable transform indicator.";
    end;
    else transform=.;

    *** output to temporary dataset that will be merged on with others storing all the main VARNAMEs;
    if source=1 and compress(varname) ne "" then output new_variable;

    *** Now start gathering info on other variables referenced in VARDEFSs;
    *** starting with variables determining the universe for VARNAME;
    if source=1 then do;
      %if &ever_out_of_universe.=1 %then %do;
        %if "&universe_determinants."~="" %then %do;
          %let i=1;
          %do %until("%scan(&universe_determinants.,&i.)"="");
            %let tmp=%scan(&universe_determinants.,&i.);
            outvar=varname;
            %standardize_varname(&tmp.,check_name,1);
            check_type=1; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
            invar=check_name;
            if compress(invar) ne "" then output new_io_pairs;
            %let i=%eval(&i.+1);
          %end;
        %end;
      %end;
    end;
    *** Now store imputation constraints (if any);
    call symput("constraints","0");
    if model in (2,3) then do;
      call symput("constraints","1");
      %if "&minimum_variable."~="" %then %do;
        outvar=varname;
        %standardize_varname(&minimum_variable.,check_name,1);
        check_type=7; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
      %end;
      %if "&maximum_variable."~="" %then %do;
        outvar=varname;
        %standardize_varname(&maximum_variable.,check_name,1);
        check_type=8; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
      %end;
      %let i=1;
      %do %until("%scan(&inputs.,&i.)"="");
        %let tmp=%scan(&inputs.,&i.);
        outvar=varname;
        %standardize_varname(&tmp.,check_name,1);
        check_type=1; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
        invar=check_name;
        if compress(invar) ne "" then output new_io_pairs;
        %let i=%eval(&i.+1);
      %end;
    end;
    *** Now store variables that are being made temporarily for modeling purposes;
    if source=0 then do;
      %if "&outputs."~="" %then %do;
        %let j=1;
        %do %until("%scan(&outputs.,&j.)"="");
          %let tmp2=%scan(&outputs.,&j.);
          %standardize_varname(&tmp2.,check_name,1);
          %if &j.=1 %then %do;
            varname=check_name;
            if compress(check_name) ne "" then output new_variable;
          %end;
          check_type=3; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
          %let j=%eval(&j.+1);
        %end;
      %end;
      %else %do;
        put "ERROR: OUTPUTS list empty in a VARDEFS defining temporary variables to be used for modeling purposes";
      %end;
    end;
    *** Now store variables used to stratify sample for model estimation;
    if model in (1,2,3) then do;
      %if "&num_lists."="" %then %do;
        put "ERROR: The number of different stratification strategies (NUM_LISTS)";
        put "ERROR: was not specified for the model of &variable.";
      %end;
      %else %do;
        %do j=1 %to &num_lists.;
          %if "&&stratifiers&j.."~="" %then %do;
            %let i=1;
            %do %until("%scan(&&stratifiers&j..,&i.)"="");
              %let tmp=%scan(&&stratifiers&j..,&i.);
              %standardize_varname(&tmp.,check_name,1);
              check_type=4; check_list=&j.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
              %let i=%eval(&i.+1);
            %end;
          %end;
          %else %do;
            check_name="_constant_"; check_type=4; check_list=&j.; check_transform=.;
            output new_vars_referenced;
          %end;
        %end;
      %end;
    end;
    *** Now store variables to be used on the right-hand-side of regression models;
    if model in (2,3) then do;
      %if "&regressors_notransform."~="" %then %do;
        %let i=1;
        %do %until("%scan(&regressors_notransform.,&i.)"="");
          %let tmp=%scan(&regressors_notransform.,&i.);
          %standardize_varname(&tmp.,check_name,1);
          check_type=5; check_list=.; check_transform=0; if compress(check_name) ne "" then output new_vars_referenced;
          %let i=%eval(&i.+1);
        %end;
      %end;
      %if "&regressors_transform."~="" %then %do;
        %let i=1;
        %do %until("%scan(&regressors_transform.,&i.)"="");
          %let tmp=%scan(&regressors_transform.,&i.);
          %standardize_varname(&tmp.,check_name,1);
          check_type=5; check_list=.; check_transform=1; if compress(check_name) ne "" then output new_vars_referenced;
          %let i=%eval(&i.+1);
        %end;
      %end;
      %if "&interactions."~="" %then %do;
        %let i=1;
        %do %until("%scan(&interactions.,&i.,' ')"="");
          %let tmp=%scan(&interactions.,&i.,' ');
          %standardize_varname(&tmp.,interaction_term,1);
          output interactions;
          %let i=%eval(&i.+1);
        %end;
      %end;
      %else %do;
        interaction_term=" ";
        output interactions;
      %end;
    end;
    *** Now store variables that will be bootstrapped simultaneously with VARNAME;
    if model in (1) then do;
      %if "&outputs."~="" %then %do;
        %let i=1;
        %do %until("%scan(&outputs.,&i.)"="");
          %let tmp=%scan(&outputs.,&i.);
          %standardize_varname(&tmp.,check_name,1);
          check_type=6; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
          %let i=%eval(&i.+1);
        %end;
      %end;
    end;
    *** Now store variables that are being created on the permanent file after imputation of certain variables;
    %if "&pi_outputs."~="" %then %do;
      %let i=1;
      %do %until("%scan(&pi_outputs.,&i.)"="");
        %let tmp=%scan(&pi_outputs.,&i.);
        %standardize_varname(&tmp.,check_name,1);
        check_type=6; check_list=.; check_transform=.; if compress(check_name) ne "" then output new_vars_referenced;
        %let i=%eval(&i.+1);
      %end;
    %end;
  run;
  *** Append metadata from a single VARDEFS file together with metadata from the rest of the VARDEFS files;
  data metadata.master_variable_list;
    set %if &numvars.>1 %then %do; metadata.master_variable_list %end; new_variable;
  run;
  data calc_io_pairs;
    set %if &numvars.>1 %then %do; calc_io_pairs %end; new_io_pairs;
  run;
  data metadata.interactions;
    set %if &numvars.>1 %then %do; metadata.interactions %end; interactions;
  run;
  %local obs_check;
  %let obs_check=0;
  data _null_;
    set new_vars_referenced;
    call symput("obs_check","1");
    stop;
  run;
  %if &obs_check.=1 %then %do;
    proc sort data=new_vars_referenced;
      by varname check_name check_type check_list;
    run;
    data new_vars_referenced;
      set new_vars_referenced;
      by varname check_name check_type check_list;
      if last.check_list then output;
    run;
    data all_vars_referenced;
      set %if &numvars.>1 %then %do; all_vars_referenced %end; new_vars_referenced;
    run;
  %end;

  /*************************************
   Build the macro (which will be stored
   in the metadata/calculate_macro1.sas)
   to calculate variables which will 
   be used to constrain the imputation
   of &variable..
   This section expects the following
   macros/macro-variables to already be
   defined:
     from VARDEFS_&variable..sas:
       &variable.
       &model_method.
       %calculate_constraints
     from prog01_build_metadata.sas:
       &workdir.
  *************************************/
  %if &constraints.=1 %then %do;
    data _null_;
      file calcmac1 mod;
      put "%nrstr(%if &curvar.=)&variable. %nrstr(%then %do;)";
    run;
    data _null_;
      set inlib.&infilename. (obs=1);
      filename mprint "&workdir./calc_code.sas";
      options mfile mprint;
      *** imputation constraints for &curvar.;
      %calculate_constraints
      options nomfile nomprint;
    run;
    data _null_;
      infile "&workdir./calc_code.sas";
      input;
      file calcmac1 mod;
      put _infile_;
    run;
    data _null_;
      fname="calc_tmp";
      rc=filename(fname,"&workdir./calc_code.sas");
      if rc=0 and fexist(fname) then rc=fdelete(fname);
      rc=filename(fname);
    run;
    data _null_;
      file calcmac1 mod;
      put "%nrstr(%end;)";
    run;
  %end;
  /*************************************
   Build the macro (which will be stored
   in the metadata/calculate_macro2.sas)
   and metadata/calculate_macro2.sas) to 
   to calculate variables for the 
   purposes of modeling other variables.
   This section expects the following
   macros/macro-variables to already be
   defined:
     from VARDEFS_&variable..sas:
       &model_method.
       %calculate_variable
     from prog01_build_metadata.sas:
       &workdir.
  *************************************/
  %if "&model_method."="." %then %do;
    data _null_;
      set inlib.&infilename. (obs=1);
      filename mprint "&workdir./calc_code.sas";
      options mfile mprint;
      *** some temporary variables for modeling purposes;
      %calculate_variable
      options nomfile nomprint;
    run;
    data _null_;
      infile "&workdir./calc_code.sas";
      input;
      file calcmac2 mod;
      put _infile_;
    run;
    data _null_;
      fname="calc_tmp";
      rc=filename(fname,"&workdir./calc_code.sas");
      if rc=0 and fexist(fname) then rc=fdelete(fname);
      rc=filename(fname);
    run;
  %end;
  %else %do;
    /*************************************
     Build the macro (which will be stored
     in the metadata/select_universe.sas)
     to print the appropriate condition for
     when a given variable is in universe.
     This section expects the following
     macros/macro-variables to already be
     defined:
       from VARDEFS_&variable..sas:
         &variable.
         &ever_out_of_universe.
         %universe_condition
       from prog01_build_metadata.sas:
         &workdir.
    *************************************/
    data _null_;
      file sel_uni mod;
      put "%nrstr(  %if &var.=)&variable. %nrstr(%then %do;)";
      %if &ever_out_of_universe.=1 %then %do;
        put "    %universe_condition";
      %end;
      %else %do;
        put "    1";
      %end;
      put "%nrstr(  %end;)";
    run;
    /*************************************
     Build the macro (which will be stored
     in the metadata/calculate_macro3.sas)
     to calculate additional variables 
     and/or edit &variable. after the 
     imputation of &variable..
     This section expects the following
     macros/macro-variables to already be
     defined:
       from VARDEFS_&variable..sas:
         &variable.
         &model_method.
         %post_impute
       from prog01_build_metadata.sas:
         &workdir.
    *************************************/
    data _null_;
      file calcmac3 mod;
      put "%nrstr(%if &curvar.=)&variable. %nrstr(%then %do;)";
    run;
    data _null_;
      set inlib.&infilename. (obs=1);
      filename mprint "&workdir./calc_code.sas";
      options mfile mprint;
      *** post imputation edit for &curvar.;
      %post_impute
      options nomfile nomprint;
    run;
    data _null_;
      infile "&workdir./calc_code.sas";
      input;
      file calcmac3 mod;
      put _infile_;
    run;
    data _null_;
      fname="calc_tmp";
      rc=filename(fname,"&workdir./calc_code.sas");
      if rc=0 and fexist(fname) then rc=fdelete(fname);
      rc=filename(fname);
    run;
    data _null_;
      file calcmac3 mod;
      put "%nrstr(%end;)";
    run;
    /*************************************
     Build the macro (which will be stored
     in the metadata/drop_macro.sas)
     to specify which (if any) variables
     should be dropped from the working
     file after running the post-imputation
     edits for &variable.. 
     This section expects the following
     macros/macro-variables to already be
     defined:
       from VARDEFS_&variable..sas:
         &variable.
         &model_method.
         &drop_vars.
       from prog01_build_metadata.sas:
         &workdir.
    *************************************/
    data _null_;
      file dropvars mod;
      put "%nrstr(%if &curvar.=)&variable. %nrstr(%then %do;)";
      if "&drop_vars." ne "" then do;
        put " (drop=&drop_vars.)";
      end;
      put "%nrstr(%end;)";
    run;
  %end;
  %blank_macros;
%mend;




