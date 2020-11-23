
/*** Description of inputs
estimation_set = input sas dataset contains complete dependent and independent variable info
imputation_set = output sas dataset (can be the same as estimation_set) contains complete independent variable info
y              = name of variable in estimation_set to be imputed under a logistic regression model
x              = names of variables in estimation_set to use on RHS of logistic regression
transform_list = names of variables in x whose distribution should be transformed to standard normal
                 before estimation/imputation
seed           = random number generator seed
minvar         = name of variable on imputation_set that contains minimum value for draw of y
                 (default of minvar being an empty string means there is no such variable)
maxvar         = name of variable on imputation_set that contains maximum value for draw of y
                 (default of maxvar being an empty string means there is no such variable)
suffix         = suffix for temporary files so that macro will not overwrite jobs running in parallel in same workspace
***/

%macro logit_impute(estimation_set,imputation_set,y,x,transform_list,interactions=,seed=0,minvar=,maxvar=,suffix=);

  %local estimation_set imputation_set y x transform_list interactions seed minvar maxvar suffix;
  %local max_nobs nmiss nobs i j numvals num_x estobs var num_xkeep xkeep num_xactions xaction_list done tmp;
  %let max_nobs=10000;

  %let done=0;
  %let num_x=0;
  %let i=1;
  %do %until("%scan(&x.,&i.)"="");
    %let num_x=&i.;
    %let i=%eval(&i.+1);
  %end;
  %let num_xactions=0;
  %let xaction_list=;
  %if "&interactions."~="" %then %do;
    %let i=1;
    %do %until("%scan(&interactions.,&i.,' ')"="");
      %let num_xactions=&i.;
      %let xaction_list=&xaction_list. _xaction&i.;
      %let i=%eval(&i.+1);
    %end;
  %end;

  * move imputation_set into a temporary file for this macro to use;
  * creating empty variables to eventually store imputed values;
  data incomplete&suffix.;
    set &imputation_set. (keep=&x. &minvar. &maxvar.);
    depvar=.;
    %if &num_xactions.>0 %then %do;
      %do i=1 %to &num_xactions.;
        %let tmp=%scan(&interactions.,&i.,' ');
        _xaction&i.=&tmp.;
        label _xaction&i.="&tmp.";
      %end;
    %end;
    call symput("nmiss",compress(put(_n_,12.)));
  run;
  * move estimation_set into a temporary file for this macro to use;
  data complete&suffix. (drop=&y.);
    set &estimation_set. (keep=&y. &x. where=(&y.>.Z));
    depvar=&y.;
    %if &num_xactions.>0 %then %do;
      %do i=1 %to &num_xactions.;
        %let tmp=%scan(&interactions.,&i.,' ');
        _xaction&i.=&tmp.;
        label _xaction&i.="&tmp.";
      %end;
    %end;
    call symput("nobs",compress(put(_n_,12.)));
  run;
  %if &nobs.>&max_nobs. %then %let estobs=&max_nobs.;
  %else %let estobs=&nobs.;
  proc freq data=&estimation_set. noprint;
    tables &y. /out=ytable&suffix. (keep=&y. count percent);
  run;
  %let numvals=0;
  data _null_;
    set ytable&suffix. end=lastobs;
    retain numvals 0;
    numvals=numvals+1;
    /***
     if proportion of estimation set where y equals any one value is too close to 1
     then go to the simple case of drawing from the univariate distribution
     ie running logistic regression with just a constant
    ***/
    if abs(1-(percent/100))<0.002 then do;
      call symput("x","");
      call symput("num_x","0");
    end;
    if lastobs then call symput("numvals",compress(put(numvals,12.)));
  run;
  %if &numvals.<2 %then %do;
    %let x=;
    %let num_x=0;
  %end;

  *** Time for variable selection;
  %if &num_x.>0 %then %do;
    /***
      Take a Bayes bootstrap of estimation set prior to variable selection
      and model estimation. Using the point estimates from a regression on
      a Bayes bootstrapped sample is essentially equivalent to taking a 
      draw from the approximate distribution of parameters estimated
      on the original sample.
    ***/
    %fastbb(complete&suffix.,bbcomplete&suffix.,depvar &x. &xaction_list.,outsize=&estobs.,seed=&seed.,suffix=&suffix.);
    %let seed=&outseed.;
    data bbformeans&suffix.;
      set bbcomplete&suffix.;
    run;
    * estimate distributions of any x where transform is requested by transform_list;
    %if "&transform_list."~="" %then %do;
      %let i=1;
      %do %until("%scan(&transform_list.,&i.)"="");
        %let tmp=%scan(&transform_list.,&i.);
        %tfile(&tmp.,bbcomplete&suffix.,tx&i._&suffix.,suffix=&suffix.);
        %let i=%eval(&i.+1);
      %end;
    %end;

    /***
      An automated process like this with potentially very many
      explanatory variables and potentially very small estimation sets
      can lead to complete/quasi-complete separation of data points problems
      with logistic regression. To avoid these computational problems
      we impose a weak prior that every combination of explanatory variables
      has some positive probability of being associated with each outcome
      of the dependent variable. We do this by augmenting the data matrix, [Y X],
      with [1-Y X]. Then we perform a weighted regression where all the added
      rows of the data matrix sum up in weight to the weight that just one row
      from the original data matrix receives (thus it is a weak prior that
      should be overwhelmed by the observed data).
    ***/
    data bbcomplete&suffix. (keep=_id_ depvar &x. _w_ _imputation_);
      set bbcomplete&suffix. (in=aa keep=depvar &x.) incomplete&suffix. (in=bb keep=depvar &x. &minvar. &maxvar.);
      retain _id_ 0;
      _id_=_id_+1;
      if bb then do;
        _imputation_=1;
        output;
      end;
      else do;
        _imputation_=0;
        _setstop_=0; _k_=0;
        do until(_setstop_=1);
          _k_=_k_+1;
          set ytable&suffix. (keep=&y. rename=(&y.=_y_)) point=_k_;
          if _error_=1 then do;
            _k_=0;
            _setstop_=1;
            _error_=0;
          end;
          else do;
            _orig_=depvar;
            if depvar=_y_ then _w_=1;
            else do;
              _w_=1/((&numvals.-1)*&estobs.);
              depvar=_y_;
            end;
            output;
            depvar=_orig_;
          end;
        end;
      end;
    run;
    * perform any transformations to x requested in transform_list;
    %if "&transform_list."~="" %then %do;
      %let i=1;
      %do %until("%scan(&transform_list.,&i.)"="");
        %let tmp=%scan(&transform_list.,&i.);
        %transform(&tmp.,bbcomplete&suffix.,tx&i._&suffix.,idvar=none,suffix=&suffix.);
        %let i=%eval(&i.+1);
      %end;
    %end;
    %if &num_xactions.>0 %then %do;
      data bbcomplete&suffix.;
        set bbcomplete&suffix.;
        %do i=1 %to &num_xactions.;
          %let tmp=%scan(&interactions.,&i.,' ');
          _xaction&i.=&tmp.;
          %let x=&x. _xaction&i.;
        %end;
      run;
      %let num_x=%eval(&num_x.+&num_xactions.);
    %end;

    proc logistic data=bbcomplete&suffix. outest=results&suffix. noprint;
      model depvar=&x. /selection=stepwise slentry=0.1 slstay=0.1 link=glogit;
      weight _w_;
      output out=bbcomplete&suffix. pred=_phat_;
    run;
    proc logistic data=bbcomplete&suffix. outest=null_results&suffix. noprint;
      model depvar= /link=glogit;
      weight _w_;
    run;
    data null_results&suffix.;
      set results&suffix. (keep=_lnlike_);
      set null_results&suffix. (keep=_lnlike_ rename=(_lnlike_=_lnlike0_));
      R2McF=1-(_lnlike_/_lnlike0_);
    run;
    data _null_;
      set results&suffix.;
      if _status_="0 Converged" then call symput("done","1");
    run;
    %if &done.=1 %then %do;
      * put pruned regressor list into macro variables;
      %let num_xkeep=0;
      %let xkeep=;
      %do j=1 %to &numvals.;
        %local yval&j.;
        data _null_;
          setpoint=&j.;
          set ytable&suffix. point=setpoint;
          call symput("yval&j.",compress(put(&y.,12.)));
          stop;
        run;
      %end;
      data prnt_results&suffix. (keep=_regressor_ _level_:);
        set results&suffix.;
        length _regressor_ $32.;
        _regressor_="Intercept";
        %do j=1 %to %eval(&numvals.-1);
          _level_&&yval&j..=Intercept_&&yval&j..;
        %end;
        output;
        _k_=0;
        %let i=1;
        %do %until("%scan(&x.,&i.)"="");
          %let var=%scan(&x.,&i.);
          _regressor_="&var.";
          %local x&i.;
          _flag_=0;
          %do j=1 %to %eval(&numvals.-1);
            if &var._&&yval&j..>. then _flag_=1;
            _level_&&yval&j..=&var._&&yval&j..;
          %end;
          if _flag_=1 then do;
            _k_=_k_+1;
            call symput("x" || compress(put(_k_,12.)),compress("&var."));
            output;
          end;
          %let i=%eval(&i.+1);
        %end;
        call symput("num_xkeep",compress(put(_k_,12.)));
      run;
      %do i=1 %to &num_xkeep.;
        %let xkeep=&xkeep. &&x&i..;
      %end;
      %let x=&xkeep.;
      %let num_x=&num_xkeep.;
    %end;
    %else %do;
      data _null_;
        file PRINT;
        put "Logistic model did not converge.";
      run;
      %let x=;
      %let num_x=0;
    %end;
  %end;

  %if &x.~= %then %do;
    * some quick summary stats for quality assurance;
    options nolabel;
    proc means data=complete&suffix.;
      var &x.;
      title1 "Means of XVARS on original estimation set";
    run;
    proc means data=bbformeans&suffix.;
      var &x.;
      title1 "Means of XVARS on bootstrap of estimation set";
    run;
    proc means data=incomplete&suffix.;
      var &x.;
      title1 "Means of XVARS on imputation set";
    run;
    proc print data=null_results&suffix.;
      var R2McF;
      title1 "McFadden R-Sqaured";
    run;
    proc print data=prnt_results&suffix.;
      title1 "Logistic regression results";
      title2 "Input dataset: &estimation_set.";
    run;
    * take draws for imputed values;
    data incomplete&suffix. (keep=&y.);
      set bbcomplete&suffix. (where=(_imputation_=1)) end=lastobs;
      by _id_ _level_;
      retain seed &seed.;
      retain &y. _cumul_ _x_;
      if first._id_ then do;
        &y.=.; _cumul_=0;
        call ranuni(seed,_x_);
      end;
      _cumul_=_cumul_+_phat_;
      if _x_ le _cumul_ and &y.=. then &y.=_level_;
      %if "&minvar."~="" %then %do;
        if &minvar.>.Z and &y.<&minvar. then &y.=.;
      %end;
      %if "&maxvar."~="" %then %do;
        if &maxvar.>.Z and &y.>&maxvar. then &y.=.;
      %end;
      if last._id_ then do;
        if &y.=. then do;
          %if &numvals.=2 %then %do;
            setpoint=1;
            set ytable&suffix. (keep=&y. rename=(&y.=_yval_)) point=setpoint;
            if _yval_ ne _level_ then &y.=_yval_;
            else do;
              setpoint=2;
              set ytable&suffix. (keep=&y. rename=(&y.=_yval_)) point=setpoint;
              &y.=_yval_;
            end;
          %end;
          %else %do;
            &y.=_level_;
          %end;
        end;
        output;
      end;
      if lastobs then call symput("seed",compress(put(seed,12.)));
    run;
  %end;
  %else %do;
    * otherwise Bayes bootstrap to generate imputed values;
    %fastbb(complete&suffix.,incomplete&suffix.,depvar,outsize=&nmiss.,seed=&seed.,suffix=&suffix.);
    data incomplete&suffix. (keep=&y.);
      set incomplete&suffix.;
      &y.=depvar;
    run;
    data _null_;
      file PRINT;
      put "Bayes bootstrap was used for imputation.";
    run;
    %let seed=&outseed.;
    %let done=1;
  %end;

  * reassemble completed data in original order from estimation_set;
  data &imputation_set.;
    set &imputation_set. (drop=&y.);
    set incomplete&suffix.;
  run;

  * clean up workspace;
  proc datasets library=work nolist;
    delete incomplete&suffix. complete&suffix.;
    %if %sysfunc(exist(results&suffix.)) %then %do;
      delete results&suffix.;
    %end;
    %if %sysfunc(exist(prnt_results&suffix.)) %then %do;
      delete prnt_results&suffix.;
    %end;
    %if %sysfunc(exist(null_results&suffix.)) %then %do;
      delete null_results&suffix.;
    %end;
    %if %sysfunc(exist(betas&suffix.)) %then %do;
      delete betas&suffix.;
    %end;
    %if %sysfunc(exist(bbcomplete&suffix.)) %then %do;
      delete bbcomplete&suffix.;
    %end;
    %if %sysfunc(exist(bbformeans&suffix.)) %then %do;
      delete bbformeans&suffix.;
    %end;
    %if "&transform_list."~="" %then %do;
      %let i=1;
      %do %until("%scan(&transform_list.,&i.)"="");
        delete tx&i._&suffix.;
        %let i=%eval(&i.+1);
      %end;
    %end;
  run;

  %global outseed;
  %let outseed=&seed.;
%mend;


