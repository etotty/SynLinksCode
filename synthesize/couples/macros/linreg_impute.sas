
/*** Description of inputs
estimation_set = input sas dataset contains complete dependent and independent variable info
imputation_set = output sas dataset (can be the same as estimation_set) contains complete independent variable info
y              = name of variable in estimation_set to be imputed under a linear regression model
transform_flag = flag indicating whether distribution of y should be transformed to standard normal
                 before estimation and transformed back to original distribution after imputation (1=yes, 0=no)
x              = names of variables in estimation_set to use on RHS of linear regression
transform_list = names of variables in x whose distribution should be transformed to standard normal
                 before estimation/imputation
seed           = random number generator seed
minvar         = name of variable on imputation_set that contains minimum value for draw of y
                 (default of minvar being an empty string means there is no such variable)
maxvar         = name of variable on imputation_set that contains maximum value for draw of y
                 (default of maxvar being an empty string means there is no such variable)
suffix         = suffix for temporary files so that macro will not overwrite jobs running in parallel in same workspace
***/

%macro linreg_impute(estimation_set,imputation_set,y,transform_flag,x,transform_list,interactions=,seed=0,minvar=,maxvar=,suffix=);

  %local estimation_set imputation_set y transform_flag x transform_list interactions seed minvar maxvar suffix;
  %local max_nobs nmiss nobs i num_x num_xactions xaction_list estobs var num_xkeep xkeep tmp ystd do_reg maxstep;
  %let max_nobs=10000;

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
    %if "&minvar."~="" %then %do; _min_depvar_=&minvar.; %end; %else %do; _min_depvar_=.; %end;
    %if "&maxvar."~="" %then %do; _max_depvar_=&maxvar.; %end; %else %do; _max_depvar_=.; %end;
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
    _min_depvar_=.;
    _max_depvar_=.;
    call symput("nobs",compress(put(_n_,12.)));
  run;
  %if &nobs.>&max_nobs. %then %let estobs=&max_nobs.;
  %else %let estobs=&nobs.;

  *** Time for variable selection;
  %if &num_x.>0 %then %do;
    /***
      Take a Bayes bootstrap of estimation set prior to variable selection
      and model estimation. Using the point estimates from a regression on
      a Bayes bootstrapped sample is essentially equivalent to taking a 
      draw from the approximate distribution of parameters estimated
      on the original sample.
    ***/
    %fastbb(complete&suffix.,bbcomplete&suffix.,depvar &x. &xaction_list. _min_depvar_ _max_depvar_,
      outsize=&estobs.,seed=&seed.,suffix=&suffix.);
    %let seed=&outseed.;
    data bbformeans&suffix.;
      set bbcomplete&suffix.;
    run;
    * estimate distributions of y and any x where transform is requested by transform_flag and transform_list;
    %if "&transform_list."~="" %then %do;
      %let i=1;
      %do %until("%scan(&transform_list.,&i.)"="");
        %let tmp=%scan(&transform_list.,&i.);
        %tfile(&tmp.,bbcomplete&suffix.,tx&i._&suffix.,suffix=&suffix.);
        %let i=%eval(&i.+1);
      %end;
    %end;
    %if &transform_flag.=1 %then %do;
      %tfile(depvar,bbcomplete&suffix.,ty_&suffix.,suffix=&suffix.);
    %end;

    * perform linear regression and collect output;
    data bbcomplete&suffix.;
      set bbcomplete&suffix. (in=aa keep=depvar &x. _min_depvar_ _max_depvar_)
          incomplete&suffix. (in=bb keep=depvar &x. _min_depvar_ _max_depvar_);
      if bb then _imputation_=1;
      else _imputation_=0;
    run;
    * perform any transformations to x and y requested in transform_flag and transform_list;
    %if "&transform_list."~="" %then %do;
      %let i=1;
      %do %until("%scan(&transform_list.,&i.)"="");
        %let tmp=%scan(&transform_list.,&i.);
        %transform(&tmp.,bbcomplete&suffix.,tx&i._&suffix.,idvar=none,suffix=&suffix.);
        %let i=%eval(&i.+1);
      %end;
    %end;
    %if &transform_flag.=1 %then %do;
      %transform(depvar,bbcomplete&suffix.,ty_&suffix.,idvar=none,suffix=&suffix.);
      %if "&minvar."~="" %then %do;
        %transform(_min_depvar_,bbcomplete&suffix.,ty_&suffix.,idvar=none,suffix=&suffix.);
      %end;
      %if "&maxvar."~="" %then %do;
        %transform(_max_depvar_,bbcomplete&suffix.,ty_&suffix.,idvar=none,suffix=&suffix.);
      %end;
    %end;

    proc means data=bbcomplete&suffix. noprint;
      var depvar;
      output out=ystd&suffix. (keep=_ystd_) std(depvar)=_ystd_;
    run;
    %let do_reg=0;
    data _null_;
      set ystd&suffix.;
      if _ystd_>0 then call symput("do_reg","1");
      call symput("maxstep",compress(put(ceil(&estobs./4),12.)));
    run;
    %if &do_reg.=1 %then %do;
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

      proc reg data=bbcomplete&suffix. outest=results&suffix. edf noprint;
        model depvar=&x. /selection=stepwise slentry=0.05 slstay=0.05 maxstep=&maxstep.;
        output out=bbcomplete&suffix. p=_yhat_;
      run;
      * put pruned regressor list into macro variables;
      %let num_xkeep=0;
      %let xkeep=;
      data _null_;
        set results&suffix.;
        _k_=0;
        %let i=1;
        %do %until("%scan(&x.,&i.)"="");
          %let var=%scan(&x.,&i.);
          %local x&i.;
          if &var.>. then do;
            _k_=_k_+1;
            call symput("x" || compress(put(_k_,12.)),compress("&var."));
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
      %if "&x."="" %then %let x=none;
    %end;
    %else %do;
      %let x=;
      %let num_x=0;
    %end;
  %end;

  %if &x.~= %then %do;
    * some quick summary stats for quality assurance;
    options nolabel;
    %if &x.=none %then %do;
      %let x=;
    %end;
    %else %do;
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
    %end;
    proc print data=results&suffix.;
      var _rsq_;
      title "R-Squared";
    run;
    proc transpose data=results&suffix. (keep=Intercept &x.) out=betas&suffix. (rename=(col1=beta));
    proc print data=betas&suffix.;
      var _name_ beta;
      title1 "OLS regression results";
      title2 "Input dataset: &estimation_set.";
    run;
    * take draws for imputed values;
    data incomplete&suffix. (keep=&y.);
      set bbcomplete&suffix. (where=(_imputation_=1)) end=lastobs;
      if _n_=1 then set results&suffix. (keep=_rmse_);
      if _n_=1 then set ystd&suffix. (keep=_ystd_);
      if _rmse_ le 0 then _rmse_=_ystd_/100;
      retain seed &seed.;
      * change constraints to quantile of normal with mean, _yhat_, and variance, _rmse_**2;
      _zmin_=probit(0.00001);
      _zmax_=probit(1-0.00001);
      if _min_depvar_>.Z then _min_=cdf('NORMAL',min(_zmax_,max(_zmin_,(_min_depvar_-_yhat_)/_rmse_)));
      else _min_=0;
      if _max_depvar_>.Z then _max_=cdf('NORMAL',min(_zmax_,max(_zmin_,(_max_depvar_-_yhat_)/_rmse_)));
      else _max_=1;
      * take a draw of error term with mean, 0, and variance, _rmse_**2;
      * conditional on probit(_min_)<error<probit(_max_);
      call ranuni(seed,_x_);
      _x_=probit(_min_+(_max_-_min_)*_x_);
      &y.=_yhat_+_rmse_*_x_;
      * quick fix if the constraints did not work properly because of extreme imputations;
      if _min_depvar_>.Z and _max_depvar_>.Z then do;
        if &y.<_min_depvar_ then do;
          call ranuni(seed,_x_);
          &y.=_min_depvar_+(min(_ystd_,_max_depvar_-_min_depvar_))*(_x_**(2+((_min_depvar_-&y.)/_ystd_)));
        end;
        if &y.>_max_depvar_ then do;
          call ranuni(seed,_x_);
          &y.=_max_depvar_-(min(_ystd_,_max_depvar_-_min_depvar_))*(_x_**(2+((&y.-_max_depvar_)/_ystd_)));
        end;
      end;
      else if _min_depvar_>.Z then do;
        if &y.<_min_depvar_ then do;
          call ranuni(seed,_x_);
          &y.=_min_depvar_+(_ystd_)*(_x_**(2+((_min_depvar_-&y.)/_ystd_)));
        end;
      end;
      else if _max_depvar_>.Z then do;
        if &y.>_max_depvar_ then do;
          call ranuni(seed,_x_);
          &y.=_max_depvar_-(_ystd_)*(_x_**(2+((&y.-_max_depvar_)/_ystd_)));
        end;
      end;
      if lastobs then call symput("seed",compress(put(seed,12.)));
    run;
    * perform reverse transformation on y if requested by transform_flag;
    %if &transform_flag.=1 %then %do;
      %reverse(&y.,incomplete&suffix.,ty_&suffix.,idvar=none,suffix=&suffix.);
    %end;
  %end;
  %else %do;
    data _null_;
      file PRINT;
      put "Bayes bootstrap was used for imputation.";
    run;
    * if not already done, Bayes bootstrap sample from estimation set;
    %fastbb(complete&suffix.,bbcomplete&suffix.,depvar,outsize=&estobs.,seed=&seed.,suffix=&suffix.);
    %let seed=&outseed.;
    * prepare incomplete data for editing;
    data incomplete&suffix.;
      set incomplete&suffix.;
      depvar=.;
    run;
    proc iml;
      use bbcomplete&suffix.;
      read all var{depvar} into yvar;
      edit incomplete&suffix.;
      read all var{_min_depvar_ _max_depvar_} into bounds;
      seed=&seed.; x=0;
      ymin=j(nrow(bounds),1,min(yvar));
      ymax=j(nrow(bounds),1,max(yvar));
      ybounds=ymin || ymax;
      if loc(bounds<=.Z) then bounds[loc(bounds<=.Z)]=ybounds[loc(bounds<=.Z)];
      if loc(bounds>max(yvar)) then bounds[loc(bounds>max(yvar))]=ybounds[loc(bounds>max(yvar))];
      if loc(bounds<min(yvar)) then bounds[loc(bounds<min(yvar))]=ybounds[loc(bounds<min(yvar))];
      depvar=j(nrow(bounds),1,.);
      * go through each row of bounds to draw imputed value from Bayes-bootstrapped sample;
      do i=1 to nrow(bounds);
        any=0;
        temp1=loc(yvar>=bounds[i,1]);
        if temp1 then do;
          temp2=loc(yvar[temp1]<=bounds[i,2]);
          if temp2 then do;
            * when the Bayes-bootstrapped sample has observation(s) falling inside the bounds;
            * choose one such observation at random as donor;
            call ranuni(seed,x);
            x=ceil(x*max(nrow(temp2) || ncol(temp2)));
            depvar[i]=yvar[temp1[temp2[x]]];
            any=1;
          end;
        end;
        if any=0 then do;
          * if no eligible donors in estimation set, simply draw from uniform distribution between bounds;
          call ranuni(seed,x);
          depvar[i]=bounds[i,1]+x*(bounds[i,2]-bounds[i,1]);
        end;
      end;
printobs=10;
if nrow(depvar)<printobs then printobs=nrow(depvar);
tmp_depvar=depvar[1:printobs,];
tmp_bounds=bounds[1:printobs,];
print tmp_depvar tmp_bounds;
      call symput("seed",char(seed));
      replace all var{depvar};
    quit;
    data incomplete&suffix. (keep=&y.);
      set incomplete&suffix.;
      &y.=depvar;
    run;
  %end;

  * reassemble completed data in original order from estimation_set;
  data &imputation_set.;
    set &imputation_set. (drop=&y.);
    set incomplete&suffix.;
  run;

  * clean up workspace;
  proc datasets library=work nolist;
    delete incomplete&suffix. complete&suffix.;
    %if %sysfunc(exist(ystd&suffix.)) %then %do;
      delete ystd&suffix.;
    %end;
    %if %sysfunc(exist(results&suffix.)) %then %do;
      delete results&suffix.;
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
    %if &transform_flag.=1 %then %do;
      delete ty_&suffix.;
    %end;
  run;

  %global outseed;
  %let outseed=&seed.;
%mend;


