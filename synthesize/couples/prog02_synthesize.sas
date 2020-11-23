
%include "config/filelocations.sas";

*** Launch each implicate of data completion in parallel;
%macro parallel_implicates;
  %let mainwork=%sysfunc(pathname(work));
  libname mainwork "&mainwork.";
  libname metadata "metadata";
  data metadata.pid_main;
    pid=&sysjobid.;
  run;
  %let last_implicate=%eval(&starting_implicate.-1+&num_implicates.);
  %do m=&starting_implicate. %to &last_implicate.;
    /***
     Initialize seeds for each implicate. If starting from 
     the beginning, start with seed specified in
     config/filelocations.sas. Otherwise, pick up where
     you left off with metadata.current_seed&m..
    ***/
    %if %sysfunc(exist(metadata.current_seed&m.))=0 %then %do;
      /***
        Generate independent starting seeds for each implicate
        in a way that can be replicated for the starting seed
        specified at the top of this program.
      ***/
      data metadata.current_seed&m. (keep=current_seed);
        seed=&seed.;
put "SEED =" seed;
        if seed>0 and &starting_implicate.>1 and &m.=&starting_implicate. then do;
          seed=&m.*seed;
          if seed>2147483646 then seed=seed-2147483646;
        end;
put "SEED =" seed;
        call ranuni(seed,x1);
        call ranuni(seed,x2);
        call ranuni(seed,x3);
        a1=min(of x1-x3);
        a2=median(of x1-x3);
        a3=max(of x1-x3);
        current_seed=ceil((a2-a1)*2147483646/(a3-a1));
put "CURRENT SEED =" current_seed;
        output;
        call symput("seed",compress(put(current_seed,12.)));
      run;
    %end;
    %else %do;
      data _null_;
        set metadata.current_seed&m.;
        call symput("seed",compress(put(current_seed,12.)));
      run;
    %end;
    /***
      Make copies of metadata so that each parallel implicate can
      access metadata simultaneously without error. Also make
      a file in the metadata folder to keep track of imputation
      progress for each implicate.
    ***/
    data mainwork.all_imputation_vars&m.;
      set metadata.all_imputation_vars;
    run;
    %if %sysfunc(exist(metadata.srmi_progress&m.))=0 or &start_from_scratch.=1 %then %do;
      data metadata.srmi_progress&m.;
        set metadata.master_variable_list;
        srmi_status=0;
      run;
    %end;
    %else %do;
      %let temp=0;
      data _null_;
        set metadata.srmi_progress&m. nobs=nobs;
        call symput("temp",compress(put(nobs,12.)));
        stop;
      run;
      %if &temp.=0 %then %do;
        data metadata.srmi_progress&m.;
          set metadata.master_variable_list;
          srmi_status=0;
        run;
      %end;
    %end;
    options sascmd="sas";
    SIGNON job&m.;
    %syslput m=&m.;
    %syslput mainwork=&mainwork.;
    %syslput num_implicates=&num_implicates.;
    %syslput last_implicate=&last_implicate.;
    %syslput num_iterations=&num_iterations.;
    %syslput nprocs=&nprocs.;
    %syslput seed=&seed.;
    %syslput infilename=&infilename.;
    %syslput outfilename=&outfilename.&m.;
    %syslput inputlib=&inputlib.;
    %syslput outputlib=&outputlib.;
    RSUBMIT process=job&m. wait=no;
      proc printto log="implicate&m..log" new;
      proc printto print="implicate&m..lst" new;
      %nrstr(%%)include "macros/srmi_syn.sas";
      %nrstr(%%)srmi;
    ENDRSUBMIT;
  %end;
  WAITFOR _ALL_ 
  %do m=&starting_implicate. %to &last_implicate.;
    job&m.
  %end;;
  %do m=&starting_implicate. %to &last_implicate.;
    RGET job&m.; 
    SIGNOFF job&m.;
  %end;
  proc datasets lib=metadata nolist;
    %do m=&starting_implicate. %to &last_implicate.;
      %if %sysfunc(exist(metadata.pid_m&m.)) %then %do;
        delete pid_m&m.;
      %end;
    %end;
    %if %sysfunc(exist(metadata.pid_main)) %then %do;
      delete pid_main;
    %end;
  run;
%mend;
%parallel_implicates;



