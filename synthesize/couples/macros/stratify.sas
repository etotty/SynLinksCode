
%macro stratify(estimation_set,imputation_set,smallest,absolute_smallest=10);
  %local estimation_set imputation_set smallest absolute_smallest;
  %local i dsid done s some_unassigned mdat lastby;
  %local mnobs check_mnobs mtmp;

  *** get observation count of imputation set, and initialize running total to check work at the end;
  %let mnobs=0; %let check_mnobs=0;
  %let dsid=%sysfunc(open(&imputation_set.));
  %if &dsid. %then %let mnobs=%sysfunc(attrn(&dsid.,NOBS));
  %let done=%sysfunc(close(&dsid.));

  /***
   Initialize indicator that last list of strata did not satisfy condition that
   every record in need of imputation matched a stratum that had enough complete
   data to satisfy estimation condition that stratum sample size>=&smallest.
  ***/
  %let some_unassigned=1;

  *** start loop through sets of stratifiers;
  %do s=1 %to &nlists.;
    %global use_list&s.;
    %let use_list&s.=0;
    %if &s.=1 %then %do;
      *** if first set, stratify the full estimation set and full imputation set by optimal list;
      %let mdat=&imputation_set.;
    %end;
    %else %do;
      *** if beyond first set, stratify full estimation set and unassigned imputation set by stratifiers&s.;
      %let mdat=msort;
    %end;
    %if &s.=&nlists. %then %let smallest=&absolute_smallest.;
    *** do we need to move on to next set of stratifiers;
    %if &some_unassigned.=1 %then %do;
      *** sort by the current list of stratifiers;
      proc sort data=&estimation_set. out=csort;
        by &&stratifiers&s.;
      run;
      proc sort data=&mdat. out=msort;
        by &&stratifiers&s.;
      run;
      /***
       Quick check to see if the coarsest stratifier list will at least
       provide an estimation set big enough for estimation for every
       stratum defined by the coarsest list on the imputation set.
      ***/
      %if &s.=1 %then %do;
        proc means data=msort noprint;
          var _idobs_;
          class &&stratifiers&nlists.;
          types 
            %let i=1;
            %do %until("%scan(&&stratifiers&nlists..,&i.)"="");
              %let lastby=%scan(&&stratifiers&nlists..,&i.);
              %if &i.=1 %then %do; &lastby. %end;
              %else %do; *&lastby. %end;
              %let i=%eval(&i.+1);
            %end;;
          output out=mcheck (keep=&&stratifiers&nlists. msize) n(_idobs_)=msize;
        run;
        proc means data=csort noprint;
          var _idobs_;
          class &&stratifiers&nlists.;
          types 
            %let i=1;
            %do %until("%scan(&&stratifiers&nlists..,&i.)"="");
              %let lastby=%scan(&&stratifiers&nlists..,&i.);
              %if &i.=1 %then %do; &lastby. %end;
              %else %do; *&lastby. %end;
              %let i=%eval(&i.+1);
            %end;;
          output out=ccheck (keep=&&stratifiers&nlists. csize) n(_idobs_)=csize;
        run;
        data _null_;
          merge mcheck (in=aa) ccheck (in=bb);
          by &&stratifiers&nlists.;
          if aa and (~bb or csize<&absolute_smallest.) then do;
            put "ERROR: All of the stratifier lists contain strata that are too small for estimation,";
            put "and/or produce strata in the imputation set that do not exist in estimation set.";
            put "The first STRATUM found that caused this error is defined by:";
            %let i=1;
            %do %until("%scan(&&stratifiers&nlists..,&i.)"="");
              %let lastby=%scan(&&stratifiers&nlists..,&i.);
              put "&lastby.=" &lastby.;
              %let i=%eval(&i.+1);
            %end;
            abort abend;
          end;
        run;
      %end;
      *** enumerate strata and measure sizes of strata in estimation set;
      %let i=1;
      %do %until("%scan(&&stratifiers&s..,&i.)"="");
        %let lastby=%scan(&&stratifiers&s..,&i.);
        %let i=%eval(&i.+1);
      %end;
      data enumeration (keep=&&stratifiers&s.. _stratum_);
        set msort (keep=_idobs_ &&stratifiers&s..);
        by &&stratifiers&s.;
        retain _stratum_ 0;
        if last.&lastby. then do;
          _stratum_=_stratum_+1;
          output;
          /***
           These are the strata based off of current stratifier list
           for which we hope to find a large enough estimation set.
          ***/
        end;
      run;
      data csort;
        merge csort (in=aa) enumeration (in=bb);
        by &&stratifiers&s.;
        if aa & bb;
      run;
      proc means data=csort noprint;
        var _stratum_;
        by _stratum_;
        output out=strata_size_list&s. (keep=_stratum_ _size_) n(_stratum_)=_size_;
      run;
      data strata_size_list&s.;
        merge enumeration (in=aa) strata_size_list&s. (in=bb);
        by _stratum_;
        if aa;
        if ~bb then _size_=0;
      run;
      proc datasets lib=work nolist;
        delete enumeration;
      run;
      /***
       Assign each stratum to 1 of &nprocs. clusters.
       Sort by size then alternate assignment to keep
       clusters roughly similar in size for the purpose
       of parallel-processing during the estimation and
       imputation phase. Strata that are not big enough
       for estimation will be assigned to _cluster_=0.
      ***/
      proc sort data=strata_size_list&s.;
        by descending _size_;
      run;
      data strata_size_list&s. (keep=_stratum_ _size_ _cluster_ &&stratifiers&s..);
        set strata_size_list&s.;
        retain _total_ 0;
        if _size_ ge &smallest. then do;
          _total_=_total_+1;
          if _total_>&nprocs. then _total_=1;
          _cluster_=_total_;
          output;
        end;
      run;
      proc sort data=strata_size_list&s.;
        by &&stratifiers&s..;
      run;
      proc print data=strata_size_list&s. (where=(_cluster_>0));
        var _stratum_ _size_ _cluster_ &&stratifiers&s..;
        title1 "Print of strata and their sizes in stratifier list &s.";
      run;
      /***
       Attach strata numbers and sizes to imputation set.
       Strata that exist in both the imputation and the estimation
       sets AND are big enough for estimation will be output to
       a cluster-list specific dataset.
       Combinations of stratifiers&s. that exist in imputation set,
       but do not exist in estimation set will be output to MSORT.
       Strata that are not big enough for estimation will be 
       output to MSORT.
      ***/
      %let mtmp=0;
      data
          %do i=1 %to &nprocs.;
            mstrata&i._list&s. (drop=_size_ _count_ _cluster_) 
          %end;
          msort (drop=_size_ _count_ _cluster_ _stratum_);
        merge msort (in=aa) strata_size_list&s. (in=bb);
        by &&stratifiers&s..;
        retain _count_ 0;
        if aa then do;
          if bb then do;
            %do i=1 %to &nprocs.;
              %if &i.>1 %then %do; else %end;
              if _cluster_=&i. then do;
                _count_=_count_+1;
                output mstrata&i._list&s.;
              end;
            %end;
          end;
          else do;
            output msort;
            call symput("some_unassigned","1");
          end;
          call symput("mtmp",compress(put(_count_,12.)));
        end;
        else if bb then do;
          put "ERROR: Something strange in STRATIFY macro.";
          put "Strata originally found in imputation set failed to find match in merge back to imputation set.";
          abort abend;
        end;
      run;
      /***
       Attach strata numbers and sizes to estimation set.
       Strata that exist in both the imputation and the estimation
       sets AND are big enough for estimation will be output to
       a cluster-list specific dataset.
      ***/
      data
          %do i=1 %to &nprocs.;
            strata&i._list&s. (drop=_size_ _cluster_ _use_) 
          %end;
          ;
        merge csort (in=aa) strata_size_list&s. (in=bb);
        by &&stratifiers&s..;
        retain _use_ 0;
        if aa & bb then do;
          %do i=1 %to &nprocs.;
            %if &i.>1 %then %do; else %end;
            if _cluster_=&i. then do;
              _use_=1;
              output strata&i._list&s.;
            end;
          %end;
          call symput("use_list&s.",compress(put(_use_,12.)));
        end;
        else if bb then do;
          put "ERROR: Something strange in STRATIFY macro.";
          put "Strata originally found in imputation set and found to be big enough for";
          put "estimation in estimation set failed to find match in merge to estimation set.";
          abort abend;
        end;
      run;

      *** sort estimation and imputation sets by strata number and then observation id (original order);
      %macro stratasort(sortfile);
        %local sortfile;
        %if %sysfunc(exist(&sortfile.)) %then %do;
          proc sort data=&sortfile.;
            by _stratum_ _idobs_;
          run;
        %end;
      %mend;
      %do i=1 %to &nprocs.;
        %stratasort(strata&i._list&s.);
        %stratasort(mstrata&i._list&s.);
      %end;

      %let check_mnobs=%eval(&check_mnobs.+&mtmp.);
    %end; /* end of if-clause some_unassigned=1 */
  %end; /* end of loop over s */

  proc datasets lib=work nolist;
    %if %sysfunc(exist(csort)) %then %do;
      delete csort;
    %end;
    %if %sysfunc(exist(msort)) %then %do;
      delete msort;
    %end;
  run;
  %put CHECK FILE SIZES:;
  %put ORIGINAL IMPUTATION SET SIZE=&mnobs.;
  %put SUM OF CHOPPED UP IMPUTATION SET SIZES=&check_mnobs.;
  title1 " ";

%mend;


