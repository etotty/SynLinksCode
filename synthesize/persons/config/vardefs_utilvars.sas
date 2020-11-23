
/*******************************************************************************************************************/
/*** SPEC WRITTEN BY: <name>, <branch>-<division> ***/


*** BASIC INFO;
/* list of names of sas variables NOT on input file which will be temporarily created before each imputation */
%let outputs=nonwhite black educ_d1 educ_d3 educ_d4 educ_d5 earncat agecat;
%macro calculate_variable;
/********************************************************
  INSIDE THE %CALCULATE_VARIABLE MACRO,
  WRITE SAS CODE THAT CREATES &VARIABLE_LIST. 
  AS THOUGH THIS CODE WAS INSIDE A SAS DATA STEP 
********************************************************/

if race=.Z then do;
  nonwhite=.Z;
  black=.Z;
end;
else do;
  if race>1 then nonwhite=1; else nonwhite=0;
  if race=2 then black=1; else black=0;
end;

if educ_5cat=.Z then do;
  educ_d1=.Z;
  educ_d3=.Z;
  educ_d4=.Z;
  educ_d5=.Z;
end;
else do;
  if educ_5cat=1 then educ_d1=1; else educ_d1=0;
  if educ_5cat=3 then educ_d3=1; else educ_d3=0;
  if educ_5cat=4 then educ_d4=1; else educ_d4=0;
  if educ_5cat=5 then educ_d5=1; else educ_d5=0;
end;

if total_der_fica_2009=.Z then earncat=.Z;
else if total_der_fica_2009 le 0 then earncat=0;
else if total_der_fica_2009 le 10000 then earncat=1;
else if total_der_fica_2009 le 50000 then earncat=2;
else if total_der_fica_2009 le 100000 then earncat=3;
else if total_der_fica_2009 le 300000 then earncat=4;
else if total_der_fica_2009 le 1000000 then earncat=5;
else earncat=6;

if sipp_birthdate=.Z then agecat=.Z; 
else if year(sipp_birthdate)>2000 then agecat=1; 
else if year(sipp_birthdate)>1990 then agecat=2; 
else if year(sipp_birthdate)>1980 then agecat=3; 
else if year(sipp_birthdate)>1970 then agecat=4; 
else if year(sipp_birthdate)>1960 then agecat=5; 
else if year(sipp_birthdate)>1950 then agecat=6; 
else if year(sipp_birthdate)>1940 then agecat=7; 
else agecat=8; 

%mend;


%ENTER_VARIABLE(.);
/*******************************************************************************************************************/


