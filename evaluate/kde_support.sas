
*** Macro to identify local maxima and check some objective criteria for disclosure concerns;
%macro kde_support(indat,invar,inkde,bandwidth);
  %local indat invar inkde bandwidth n;
  *** first find local maxima in kde;
  data _localmax_ (keep=localmax pdf_l pdf pdf_u bin_lb bin_ub bandwidth_lb bandwidth_ub);
    set &inkde. end=lastobs;
    retain lag2_density lag1_density lag2_value lag1_value;
    density=round(density,10**(-10));
    if _n_>1 then do;
      if lag2_density<lag1_density>density then do;
        localmax=lag1_value;
        pdf_l=lag2_density;
        pdf=lag1_density;
        pdf_u=density;
        if lag2_value>. then bin_lb=(lag1_value+lag2_value)/2;
        else bin_lb=lag1_value;
        bin_ub=(lag1_value+value)/2;
        bandwidth_lb=lag1_value-&bandwidth.;
        bandwidth_ub=lag1_value+&bandwidth.;
        output;
      end;
    end;
    if lastobs then do;
      if lag1_density<density then do;
        localmax=value;
        pdf_l=lag1_density;
        pdf=density;
        pdf_u=.;
        bin_lb=(lag1_value+value)/2;
        bin_ub=value;
        bandwidth_lb=value-&bandwidth.;
        bandwidth_ub=value+&bandwidth.;
        output;
      end;
    end;
    lag2_density=lag1_density;
    lag1_density=density;
    lag2_value=lag1_value;
    lag1_value=value;
  run;
  data _null_;
    set &indat. nobs=nobs;
    call symput("n",compress(put(nobs,12.)));
    stop;
  run;

  *** Now find how many points from the sample fall within these ranges of the local maxima;
  data _localmax_ (keep=localmax pdf_l pdf pdf_u bin_lb bin_ub bandwidth_lb bandwidth_ub bincount bandcount);
    set _localmax_;
    bincount=0;
    bandcount=0;
    do i=1 to &n.;
      set &indat. (keep=&invar.) point=i;
      if bin_lb<=&invar.<=bin_ub then bincount=bincount+1;
      if bandwidth_lb<=&invar.<=bandwidth_ub then bandcount=bandcount+1;
    end;
    output;
  run;
  title "KDE support for dataset=&indat., variable=&invar.";
  proc print;
%mend;





