

/********************************************************
The macro, tfile(...), is used to monotonically transform
a variable into something with a distribution that is
roughly standard normal. This is done with by estimating
the distribution of the input variable using a custom
built KDE. This custom KDE does not provide a continuous
PDF but does make a continuous (not smooth) CDF that is
equivalent to the sample CDF at each of the observed sample
points. Like a traditional KDE, there is a bandwidth concept
that allows you to put more or less weight on unobserved
points in the neighborhood of observed points. This custom
KDE also allows for a single point to receive positive probability
if there is enough sample observations at that exact point.

Once the CDF of the input variable is estimated, it can be used
to map every possible value of the input variable into
the point in the standard normal distribution with the same
value in the standard normal CDF.
********************************************************/
%macro tfile(var,infile,tfile,suffix=,weight=none);
  %local var infile tfile factor suffix weight;
  *** hard code number of grid points for kde;
  %local ng;
  %let ng=10000;
  proc means data=&infile. noprint;
    var &var.;
    %if "&weight."~="none" %then %do;
      weight &weight.;
    %end; 
    output out=quantiles&suffix. n(&var.)=n
      min(&var.)=min
      p1(&var.)=p1
      p5(&var.)=p5
      p10(&var.)=p10
      q1(&var.)=p25
      median(&var.)=p50
      q3(&var.)=p75
      p90(&var.)=p90
      p95(&var.)=p95
      p99(&var.)=p99
      max(&var.)=max
      ;
  run;
  *** for practical purposes, we bound the draws within a linear extrapolation of a (preferably) nearby quantile and the observed extrema;
  %local predmin predmax;
  data _null_;
    set quantiles&suffix.;
    /*** 
      if one has a sample {X1, ,Xn}, and one picks another observation Xn+1, then this has:
        1/(n+1) probability of being the largest value seen so far
        1/(n+1) probability of being the smallest value seen so far
        (n−1)/(n+1) probability of Xn+1 falling between the sample maximum and sample minimum
      so use these probabilities to extrapolate our prediction boundaries from our sample quantiles
    ***/
    if max>p99 then predmax=max+((max-p99)/(0.01*(n-1)));
    else if max>p95 then predmax=max+((max-p95)/(0.01*(n-1)));
    else if max>p90 then predmax=max+((max-p90)/(0.01*(n-1)));
    else if max>p75 then predmax=max+((max-p75)/(0.01*(n-1)));
    else if max>p50 then predmax=max+((max-p50)/(0.01*(n-1)));
    else if max>p25 then predmax=max+((max-p25)/(0.01*(n-1)));
    else if max>p10 then predmax=max+((max-p10)/(0.01*(n-1)));
    else if max>p5 then predmax=max+((max-p5)/(0.01*(n-1)));
    else if max>p1 then predmax=max+((max-p1)/(0.01*(n-1)));
    else predmax=max;

    if min<p1 then predmin=min-((p1-min)/(0.01*(n-1)));
    else if min<p5 then predmin=min-((p5-min)/(0.01*(n-1)));
    else if min<p10 then predmin=min-((p10-min)/(0.01*(n-1)));
    else if min<p25 then predmin=min-((p25-min)/(0.01*(n-1)));
    else if min<p50 then predmin=min-((p50-min)/(0.01*(n-1)));
    else if min<p75 then predmin=min-((p75-min)/(0.01*(n-1)));
    else if min<p90 then predmin=min-((p90-min)/(0.01*(n-1)));
    else if min<p95 then predmin=min-((p95-min)/(0.01*(n-1)));
    else if min<p99 then predmin=min-((p99-min)/(0.01*(n-1)));
    else predmin=min;

    if predmin=predmax then do;
      predmin=predmin-0.1;
      predmax=predmax+0.1;
    end;
    call symput("predmax",compress(put(predmax,12.9)));
    call symput("predmin",compress(put(predmin,12.9)));
  run;
  %let scratch=%sysfunc(pathname(work));
  proc printto log="&scratch./garbage&suffix..log" new;
  proc printto print="&scratch./garbage&suffix..lst" new;
  proc kde data=&infile.;
    univar &var. / out=kde&suffix. gridl=&predmin. gridu=&predmax. ng=&ng. method=srot bwm=0.1;
    %if "&weight."="none" %then %do;
    %end;
    %else %do;
      weight &weight.;
    %end;
  run;
  proc printto log=LOG;
  proc printto print=PRINT;
  %local cdfmax;
  %let cdfmax=0.000000000;
  data kde&suffix. (keep=&var. cdf) cdfmax&suffix. (keep=cdfmax);
    set kde&suffix. (keep=value density rename=(value=&var. density=pdf)) end=lastobs;
    retain cdf;
    retain ylag pdflag;
    if _n_=1 then cdf=0;
    else cdf=cdf+(&var.-ylag)*mean(pdf,pdflag);
    output kde&suffix.;
    ylag=&var.;
    pdflag=pdf;
    cdfmax=cdf;
    if lastobs then output cdfmax&suffix.;
    if lastobs then call symput("cdfmax",compress(put(cdf,12.9)));
  run;
  %put CDFMAX=&cdfmax.;
  %if "&cdfmax."="0.000000000" %then %do;
    *** something went wrong with the kde so just use sample order;
    proc sort data=&infile. (keep=&var.) out=kde&suffix.;
      by &var.;
    run;
    data kde&suffix. (keep=&var.);
      set kde&suffix. end=lastobs;
      if _n_=1 then do;
        _original=&var.;
        &var.=&predmin.;
        output;
        &var.=_original;
      end;
      if lastobs then do;
        &var.=&predmax.;
        output;
      end;
    run;
    data &tfile. (keep=&var. cdf flag_last rename=(&var.=_var_));
      set kde&suffix. nobs=nobs;
      by &var.;
      retain cdf _count 0;
      if first.&var. then _count=0;
      _count=_count+1;
      if last.&var. then do;
        cdf=cdf+_count/(nobs);
        flag_last=0;
        if _n_=nobs then flag_last=1;
        output;
      end;
    run;
  %end;
  %else %do;
    data &tfile. (keep=&var. cdf flag_last rename=(&var.=_var_));
      set kde&suffix. end=lastobs;
      if _n_=1 then set cdfmax&suffix.;
      cdf=cdf/cdfmax;
      flag_last=0;
      if lastobs then flag_last=1;
    run;
  %end;
  proc datasets library=work nolist;
    delete quantiles&suffix.;
    delete kde&suffix.;
    delete cdfmax&suffix.;
  run;
%mend;


/********************************************************
The macro, transform(...), uses the estimated distribution
from the macro, tfile(...), to monotonically transform
a variable into something with a distribution that is
roughly standard normal.
********************************************************/
%macro transform(var,infile,tfile,idvar=none,suffix=);
  %local var infile tfile idvar suffix;
  %if &idvar.=none %then %do;
    %let idvar=_idvar_;
    data insort&suffix.;
      set &infile.;
      &idvar.=_n_;
    run;
    proc sort data=insort&suffix.;
      by &var.;
    run;
  %end;
  %else %do;
    proc sort data=&infile. (keep=&idvar. &var.) out=insort&suffix.;
      by &var.;
    run;
  %end;
  data _null_;
    set &tfile. (obs=1);
    call symput("predmin",compress(put(_var_,12.9)));
  run;
  data insort&suffix. (keep=&idvar. &var.);
    set insort&suffix.;
    retain first_set cdf_lag 0;
    retain z_lag &predmin.;
    if &var.>.Z then do;
      mincdf=10**(-10);
      maxcdf=1-mincdf;
      if z<&var. and flag_last<1 then
      do until(z ge &var. or flag_last=1);
        if first_set=1 then do;
          cdf_lag=cdf;
          z_lag=z;
        end;
        set &tfile. (rename=(_var_=z));
        first_set=1;
      end;
      if z-z_lag>0 then temp_cdf=cdf*((&var.-z_lag)/(z-z_lag))+cdf_lag*((z-&var.)/(z-z_lag));
      else temp_cdf=cdf;
      temp_cdf=min(maxcdf,max(mincdf,temp_cdf));
      &var.=probit(temp_cdf);
      output;
    end;
    else output;
  run;
  proc sort data=insort&suffix.;
    by &idvar.;
  run;
  data &infile.;
    set &infile. (drop=&var.);
    set insort&suffix. (drop=&idvar.);
  run;
  proc datasets library=work nolist;
    delete insort&suffix.;
  run;
%mend;


/********************************************************
The macro, reverse(...), uses the estimated distribution
from the macro, tfile(...), to monotonically transform
a variable with a standard normal distribution back to
the original distribution of the variable of interest.
********************************************************/
%macro reverse(var,infile,tfile,idvar=none,suffix=);
  %local var infile tfile idvar suffix;
  %if &idvar.=none %then %do;
    %let idvar=_idvar_;
    data insort&suffix.;
      set &infile.;
      &idvar.=_n_;
    run;
    proc sort data=insort&suffix.;
      by &var.;
    run;
  %end;
  %else %do;
    proc sort data=&infile. (keep=&idvar. &var.) out=insort&suffix.;
      by &var.;
    run;
  %end;
  data _null_;
    set &tfile. (obs=1);
    call symput("predmin",compress(put(_var_,12.9)));
  run;
  data insort&suffix. (keep=&idvar. &var.);
    set insort&suffix.;
    retain first_set cdf_lag 0;
    retain z_lag &predmin.;
    if &var.>.Z then do;
      temp_cdf=cdf('NORMAL',&var.,0,1);
      mincdf=10**(-10);
      maxcdf=1-mincdf;
      if cdf<temp_cdf and flag_last<1 then
      do until(cdf ge temp_cdf or flag_last=1);
        if first_set=1 then do;
          cdf_lag=cdf;
          z_lag=z;
        end;
        set &tfile. (rename=(_var_=z));
        first_set=1;
      end;
      if cdf-cdf_lag>0 then &var.=z*((temp_cdf-cdf_lag)/(cdf-cdf_lag))+z_lag*((cdf-temp_cdf)/(cdf-cdf_lag));
      else &var.=z;
      output;
    end;
    else output;
  run;
  proc sort data=insort&suffix.;
    by &idvar.;
  run;
  data &infile.;
    set &infile. (drop=&var.);
    set insort&suffix. (drop=&idvar.);
  run;
  proc datasets library=work nolist;
    delete insort&suffix.;
  run;
%mend;


