
options ls=130 nocenter noovp;
%include "macros/enter_variable.sas";
%include "macros/eval_metadata_syn.sas";
%include "macros/make_ordered_list.sas";
%include "macros/minor_functions.sas";
%include "config/filelocations.sas";

%let workdir=%sysfunc(pathname(work));

libname inlib "&inputlib.";
libname metadata "metadata";

*** read in all the variable definitions and models;
%let numvars=0;
filename calcmac1 "metadata/calculate_macro1.sas";
filename calcmac2 "metadata/calculate_macro2.sas";
filename calcmac3 "metadata/calculate_macro3.sas";
filename dropvars "metadata/drop_macro.sas";
filename sel_uni "metadata/select_universe.sas";
data _null_;
  file calcmac1;
  put "%nrstr(%macro calculate_macro1;)";
  file calcmac2;
  put "%nrstr(%macro calculate_macro2;)";
  file calcmac3;
  put "%nrstr(%macro calculate_macro3;)";
  file dropvars;
  put "%nrstr(%macro drop_macro;)";
  file sel_uni;
  put "%nrstr(%macro select_universe(var);)";
  put "%nrstr(  %local var;)";
run;
****************************************;
%blank_macros;
%include "config/vardefs_*.sas";
****************************************;
data _null_;
  file calcmac1 mod;
  put "%nrstr(%mend;)";
  file calcmac2 mod;
  put "%nrstr(%mend;)";
  file calcmac3 mod;
  put "%nrstr(%mend;)";
  file dropvars mod;
  put "%nrstr(%mend;)";
  file sel_uni mod;
  put "%nrstr(%mend;)";
run;

%evaluate_metadata;
%make_ordered_list;




