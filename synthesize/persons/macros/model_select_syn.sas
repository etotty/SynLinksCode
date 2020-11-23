
%macro model_selection;
  %local i temp digits_vars digits_iters digits_imps padded_varnum padded_n padded_m imp_reccount;
  *** print to iteration-variable-implicate specific log/lst files in srmi_logs/ subdirectory;
  data _null_;
    numvars=compress("&numvars.");
    call symput("digits_vars",compress(put(length(numvars),12.)));
    num_iterations=compress("&num_iterations.");
    call symput("digits_iters",compress(put(length(num_iterations),12.)));
    implicates=compress("&last_implicate.");
    call symput("digits_imps",compress(put(length(implicates),12.)));
  run;
  data _null_;
    call symput("padded_varnum",compress(put(&varnum.,z&digits_vars..)));
    call symput("padded_n",compress(put(&n.,z&digits_iters..)));
    call symput("padded_m",compress(put(&m.,z&digits_imps..)));
  run;
  options formdlim=" " nodate nonumber skip=0;
  proc printto log="srmi_logs/iter&padded_n._var&padded_varnum._m&padded_m..log" new;
  proc printto print="srmi_logs/iter&padded_n._var&padded_varnum._m&padded_m..lst" new;
  data _null_;
    put "NOW DOING: &curvar.";
  run;
  /***
   Use metadata to get lists of variables needed for the modeling of &curvar.
   as well as list of variables being modeled simultaneously with &curvar..
  ***/
  %model_varlists;
 
  options minoperator;
  %if &model. in 1 2 3 %then %do;
    *** divide the file up into estimation set, imputation set, and out-of-universe set;
    data estimation_set&m. (keep=_idobs_ _constant_ &curvar. &input_vars. &output_vars.);
      set inlib.&infilename. end=lastobs;
      _constant_=1;
      _idobs_=_n_;
      _variable_=compress("&curvar.");
      _level_=&level.;
      _iteration_=&n.;
      _source_=0;
      /***
       This program relies on user and feedback from prog01 to make sure all variables
       in &output_list. are equal to .Z (missing-to-be-imputed) in same places as &curvar..
      ***/
      if %select_universe(&curvar.) then do;
        *** calculate variables specified in vardefs to be created for modeling purposes only;
        %calculate_macro2;
        *** calculate variables specified in vardefs to be created for imputation constraints;
        %calculate_macro1;
        %do i=1 %to &num_inputs.;
          %let temp=%scan(&input_vars.,&i.);
          *** Set every missing value of each predictor equal to 0.;
          &temp.=sum(0,&temp.);
        %end;
        _impcount_=sum(1,_impcount_);
        output estimation_set&m.;
      end;
    run;
    %let imp_reccount=0;
    data out_of_universe&m. (keep=_idobs_ &curvar. &output_vars.)
      imputation_set&m. (keep=_idobs_ _constant_ &curvar. &input_vars. &output_vars. &min_imp_var. &max_imp_var.);
      set outlib.&outfilename. end=lastobs;
      retain _missmin_ _missmax_ _impcount_ 0;
      %if &n.=1 %then %do;
        retain zflag1-zflag&num_inputs. 0;
      %end;
      _constant_=1;
      _idobs_=_n_;
      _variable_=compress("&curvar.");
      _level_=&level.;
      _iteration_=&n.;
      _source_=1;
      /***
       This program relies on user and feedback from prog01 to make sure all variables
       in &output_list. are equal to .Z (missing-to-be-imputed) in same places as &curvar..
      ***/
      if %select_universe(&curvar.) then do;
        *** calculate variables specified in vardefs to be created for modeling purposes only;
        %calculate_macro2;
        *** calculate variables specified in vardefs to be created for imputation constraints;
        %calculate_macro1;
        %do i=1 %to &num_inputs.;
          %let temp=%scan(&input_vars.,&i.);
          *** if iteration=1 then flag every predictor that ever equals .Z;
          %if &n.=1 %then %do;
            if &temp.=.Z then zflag&i.=1;
          %end;
          *** Set every missing value of each predictor equal to 0.;
          &temp.=sum(0,&temp.);
        %end;
        &curvar.=.Z;
        %do i=1 %to &num_outputs.;
          %let temp=%scan(&output_vars.,&i.);
          &temp.=.Z;
        %end;
        _impcount_=sum(1,_impcount_);
        output imputation_set&m.;
        %if "&min_imp_var."~="" %then %do;
          if &min_imp_var. le .Z then do;
            _missmin_=sum(1,_missmin_);
            &min_imp_var.=-constant('BIG');
          end;
        %end;
        %if "&max_imp_var."~="" %then %do;
          if &max_imp_var. le .Z then do;
            _missmax_=sum(1,_missmax_);
            &max_imp_var.=constant('BIG');
          end;
        %end;
      end;
      else do;
        /***
         This program relies on user and feedback from prog01 to make sure all variables
         in &output_list. are out-of-universe if &curvar. is out-of-universe.
         When out-of-universe, this code expects (and will set) variables to 
         regular SAS missing (.).
        ***/
        &curvar.=.;
        %do i=1 %to &num_outputs.;
          %let temp=%scan(&output_vars.,&i.);
          &temp.=.;
        %end;
        output out_of_universe&m.;
      end;
      %if &n.=1 %then %do;
        if lastobs then do;
          %do i=1 %to &num_inputs.;
            call symput("zflag&i.",compress(put(zflag&i.,4.)));
          %end;
        end;
      %end;
      if lastobs then call symput("imp_reccount",compress(put(_impcount_,12.)));
      %if "&min_imp_var."~="" %then %do;
        if lastobs then do;
          if _missmin_>0 then put
          "WARNING: &min_imp_var. is specified to constrain imputation of &curvar., "
          "but it is missing in " _missmin_ " out of the " _impcount_ " observations for imputation. "
          "When &min_imp_var. is missing, no minimum will be enforced on the imputation.";
        end;
      %end;
      %if "&max_imp_var."~="" %then %do;
        if lastobs then do;
          if _missmax_>0 then put
          "WARNING: &max_imp_var. is specified to constrain imputation of &curvar., "
          "but it is missing in " _missmax_ " out of the " _impcount_ " observations for imputation. "
          "When &max_imp_var. is missing, no maximum will be enforced on the imputation.";
        end;
      %end;
    run;
    %if &n.=1 %then %do;
      /***
       If iteration=1, then set every value of predictors
       flagged in previous data step as ever equal to .Z
       equal to 0. This way variables which have not yet
       been synthesized are not used in the modeling.
       In later iterations, all variables will be used in
       the modeling.
      ***/
      data imputation_set&m.;
        set imputation_set&m.;
        %do i=1 %to &num_inputs.;
          %let temp=%scan(&input_vars.,&i.);
          %if &n.=1 %then %do;
            %if &&zflag&i..=1 %then %do;
              if _n_=1 then put "Setting &temp. to 0";
              &temp.=0;
            %end;
          %end;
        %end;
      run;
      data estimation_set&m.;
        set estimation_set&m.;
        %do i=1 %to &num_inputs.;
          %let temp=%scan(&input_vars.,&i.);
          &temp.=sum(0,&temp.);
          %if &n.=1 %then %do;
            %if &&zflag&i..=1 %then %do;
              if _n_=1 then put "Setting &temp. to 0";
              &temp.=0;
            %end;
          %end;
        %end;
      run;
    %end;

    %if &imp_reccount.>0 %then %do;
      %local smallest_regstrat;
      %let smallest_regstrat=100;
      data _null_;
        set estimation_set&m. (keep=&curvar.) nobs=nobs;
        call symput("smallest_regstrat",compress(put(max(&smallest_regstrat.,ceil(nobs/200)),12.)));
        stop;
      run;
      %if &model.=1 %then %do;
        *** variable to be imputed with Bayes Bootstrap;
        %parallel_bb;
        %let seed=&outseed.;
      %end;
      %else %if &model.=2 %then %do;
        *** variable to be imputed with Logistic Regression;
        %parallel_logit;
        %let seed=&outseed.;
      %end;
      %else %if &model.=3 %then %do;
        *** variable to be imputed with Linear Regression;
        %parallel_linreg;
        %let seed=&outseed.;
      %end;
      *** check to see if every value of &curvar. that was in universe and in need of imputation is non-missing;
      data _null_;
        set imputation_set&m. (keep=&curvar.) end=lastobs;
        retain _count_ 0;
        if &curvar. ne .Z then _count_=_count_+1;
        if lastobs and _count_=_n_ then call symput("all_clear","1");
        else if lastobs then do;
          call symput("all_clear","1");
          _remainder_=_n_=_count_;
          put "WARNING: " _remainder_ " of the " _n_ " synthesized values of &curvar. are equal to .Z";
        end;
      run;
      data imputation_set&m.;
        merge imputation_set&m. out_of_universe&m.;
        by _idobs_;
      run;
      *** put the data back together again;
      data outlib.&outfilename. %drop_macro;
        set imputation_set&m. (keep=_idobs_ &curvar. &output_vars. 
            rename=(&curvar.=_tmp0 
            %do i=1 %to &num_outputs.;
              %let temp=%scan(&output_vars.,&i.);
              &temp.=_tmp&i.
            %end;));
        modify outlib.&outfilename. point=_idobs_;
        if _error_=1 then do;
          put "ERROR occurred for _IDOBS_=" _idobs_;
          _error_=0;
          stop;
        end;
        &curvar.=_tmp0;
        %do i=1 %to &num_outputs.;
          %let temp=%scan(&output_vars.,&i.);
          &temp.=_tmp&i.;
        %end;
        *** do any post-imputation calculations specified in VARDEFS for &curvar.;
        %calculate_macro3;
      run;
    %end;
    %else %do;
      %if &syserr.=0 %then %do;
        %let all_clear=1;
        data _null_;
          file PRINT;
          put "No records in scope for imputation.";
        run;
      %end;
    %end;

  %end;

  proc datasets lib=work;
    delete imputation_set&m.;
    delete estimation_set&m.;
    delete out_of_universe&m.;
  run;
  proc printto log="implicate&m..log";
  proc printto print="implicate&m..lst";
%mend;















