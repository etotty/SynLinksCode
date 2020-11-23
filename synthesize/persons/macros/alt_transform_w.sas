

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
  *** FACTOR is a multiplier used in determining size of bandwidth (standard deviation of kernel);
  *** FACTOR must be greater than 0. The bigger the FACTOR => the bigger the bandwidth.;
  %let factor=2;
  proc sort data=&infile. out=&tfile.
    (keep=&var. %if "&weight."~="none" %then %do; &weight. %end; 
     where=(&var.>.Z));
    by &var.;
  run;
  proc means data=&tfile. noprint;
    %if "&weight."="none" %then %do;
      var &var.;
      output out=weight_sum&suffix. (keep=_wsum_) n(&var.)=_wsum_;
    %end;
    %else %do;
      var &weight.;
      output out=weight_sum&suffix. (keep=_wsum_) sum(&weight.)=_wsum_;
    %end;
  run;
  /********************************************************
   TYPE will tell whether to treat as a continuous
     cdf (type=0) or a discrete step in the cdf (type=1).
     We set type=1 if we reject hypothesis that
     Pr(&var.=zb)<0.01 at the 95% confidence level.
   ZA ZB ZC K SIGMA will give the ingredients
     for forming the normal kernels to
     define the cdf in the interval of {za,zc}
   N=number of obs in estimation set
   M=counter of distinct values in estimation set
   FLAG_LAST=indicator for last observation in tfile
  ********************************************************/
  data &tfile. (keep=n m za zb zc k sigma type flag_last);
    set &tfile. end=lastobs nobs=nobs;
    by &var.;
    if _n_=1 then set weight_sum&suffix.;
    retain count m 0;
    retain var_lag zc k_lag type_lag;
    n=nobs;
    %if "&weight."="none" %then %do;
      _w_=1;
    %end;
    %else %do;
      _w_=&weight.*n/_wsum_;
    %end;
    flag_last=0;
    if first.&var. then count=0;
    count=count+_w_;
    if last.&var. then do;
      m=m+1;
      if nobs=1 then reject=1;
      else if (count/_wsum_)+
          (tinv(0.05,_wsum_-1))*
          sqrt((count/_wsum_)*
          (1-(count/_wsum_))/(_wsum_-1))
        ge 0.01 then reject=1;
      else reject=0;
      if m>1 then do;
        m=m-1;
        k=k_lag;
        type=type_lag;
        if type=1 then do;
          za=var_lag;
          zb=var_lag;
          zc=var_lag;
          sigma=0;
        end;
        else if reject=1 then do;
          za=zc;
          zb=var_lag;
          zc=&var.;
          if za>. then sigma=max(10**(-10),&factor.*(zc-za)/k);
          else sigma=max(10**(-10),&factor.*2*(zc-zb)/k);
        end;
        else do;
          za=zc;
          zb=var_lag;
          zc=(var_lag*k/(count+k))+(&var.*count/(count+k));
          if za>. then sigma=max(10**(-10),&factor.*(zc-za)/k);
          else sigma=max(10**(-10),&factor.*2*(zc-zb)/k);
        end;
        output;
        m=m+1;
        k=count;
      end;
      if lastobs then do;
        flag_last=1;
        if m=1 then do;
          type=1;
          sigma=0;
          za=&var.;
          zb=&var.;
          zc=&var.;
          k=count;
        end;
        else do;
          type=reject;
          k=count;
          za=zc;
          zb=&var.;
          if type=1 then do;
            zc=&var.;
            sigma=0;
          end;
          else do;
            zc=.;
            sigma=max(10**(-10),&factor.*2*(zb-za)/k);
          end;
        end;
        output;
      end;
      var_lag=&var.;
      k_lag=count;
      type_lag=reject;
    end;
  run;
  proc datasets library=work nolist;
    delete weight_sum&suffix.;
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
  data insort&suffix. (keep=&idvar. &var.);
    set insort&suffix.;
    retain ksum ksum_lag 0;
    if &var.>.Z then do;
      mincdf=10**(-10);
      maxcdf=1-mincdf;
      if (zc<&var. or (zc=&var. and type=0)) and flag_last<1 then
      do until(zc>&var. or (zc=&var. and type=1) or flag_last=1);
        set &tfile.;
        ksum_lag=ksum;
        ksum=ksum+k;
      end;
      cdf_lag=ksum_lag/n;
      if type=1 then cdf=cdf_lag+k/(2*n);
      else if za>. and zc>. then cdf=cdf_lag+(k/n)*
        (cdf('NORMAL',&var.,zb,sigma)-cdf('NORMAL',za,zb,sigma))/
          (cdf('NORMAL',zc,zb,sigma)-cdf('NORMAL',za,zb,sigma));
      else if za=. then cdf=cdf_lag+(k/n)*
        (cdf('NORMAL',&var.,zb,sigma)-0)/
        (cdf('NORMAL',zc,zb,sigma)-0);
      else if zc=. then cdf=cdf_lag+(k/n)*
        (cdf('NORMAL',&var.,zb,sigma)-cdf('NORMAL',za,zb,sigma))/
        (1-cdf('NORMAL',za,zb,sigma));
      cdf=max(mincdf,min(maxcdf,cdf));
      &var.=probit(cdf);
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
  data insort&suffix. (keep=&idvar. &var.);
    set insort&suffix.;
    retain _value_;
    retain ksum ksum_lag 0;
    if &var.>.Z then do;
      tmpcdf=cdf('NORMAL',&var.,0,1);
      mincdf=10**(-10);
      maxcdf=1-mincdf;
      if _value_<tmpcdf then do until(_value_ ge tmpcdf);
        if flag_last=1 then _value_=1;
        else do;
          set &tfile.;
          ksum_lag=ksum;
          ksum=ksum+k;
          _value_=ksum/n;
        end;
      end;
      if type=1 then tmpvar=zb;
      else if za>. and zc>. then tmpvar=zb+sigma*probit(max(min(cdf('NORMAL',za,zb,sigma)+
        (cdf('NORMAL',zc,zb,sigma)-cdf('NORMAL',za,zb,sigma))*(tmpcdf-(ksum_lag/n))/(k/n),maxcdf),mincdf));
      else if za=. then tmpvar=zb+sigma*probit(max(min(0+
        (cdf('NORMAL',zc,zb,sigma)-0)*(tmpcdf-(ksum_lag/n))/(k/n),maxcdf),mincdf));
      else if zc=. then tmpvar=zb+sigma*probit(max(min(cdf('NORMAL',za,zb,sigma)+
        (1-cdf('NORMAL',za,zb,sigma))*(tmpcdf-(ksum_lag/n))/(k/n),maxcdf),mincdf));
      &var.=tmpvar;
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


