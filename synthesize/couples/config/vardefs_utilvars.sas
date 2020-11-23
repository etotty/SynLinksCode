
/*******************************************************************************************************************/
/*** SPEC WRITTEN BY: <name>, <branch>-<division> ***/


*** BASIC INFO;
/* list of names of sas variables NOT on input file which will be temporarily created before each imputation */
%let outputs=
 m_nonwhite m_black m_educ_d1 m_educ_d3 m_educ_d4 m_educ_d5 m_earncat m_agecat
 f_nonwhite f_black f_educ_d1 f_educ_d3 f_educ_d4 f_educ_d5 f_earncat f_agecat;
%macro calculate_variable;
/********************************************************
  INSIDE THE %CALCULATE_VARIABLE MACRO,
  WRITE SAS CODE THAT CREATES &VARIABLE_LIST. 
  AS THOUGH THIS CODE WAS INSIDE A SAS DATA STEP 
********************************************************/

if m_race=.Z then do;
  m_nonwhite=.Z;
  m_black=.Z;
end;
else do;
  if m_race>1 then m_nonwhite=1; else m_nonwhite=0;
  if m_race=2 then m_black=1; else m_black=0;
end;

if m_educ_5cat=.Z then do;
  m_educ_d1=.Z;
  m_educ_d3=.Z;
  m_educ_d4=.Z;
  m_educ_d5=.Z;
end;
else do;
  if m_educ_5cat=1 then m_educ_d1=1; else m_educ_d1=0;
  if m_educ_5cat=3 then m_educ_d3=1; else m_educ_d3=0;
  if m_educ_5cat=4 then m_educ_d4=1; else m_educ_d4=0;
  if m_educ_5cat=5 then m_educ_d5=1; else m_educ_d5=0;
end;

if m_total_der_fica_2009=.Z then m_earncat=.Z;
else if m_total_der_fica_2009 le 0 then m_earncat=0;
else if m_total_der_fica_2009 le 10000 then m_earncat=1;
else if m_total_der_fica_2009 le 50000 then m_earncat=2;
else if m_total_der_fica_2009 le 100000 then m_earncat=3;
else if m_total_der_fica_2009 le 300000 then m_earncat=4;
else if m_total_der_fica_2009 le 1000000 then m_earncat=5;
else m_earncat=6;

if m_sipp_birthdate=.Z then m_agecat=.Z; 
else if year(m_sipp_birthdate)>2000 then m_agecat=1; 
else if year(m_sipp_birthdate)>1990 then m_agecat=2; 
else if year(m_sipp_birthdate)>1980 then m_agecat=3; 
else if year(m_sipp_birthdate)>1970 then m_agecat=4; 
else if year(m_sipp_birthdate)>1960 then m_agecat=5; 
else if year(m_sipp_birthdate)>1950 then m_agecat=6; 
else if year(m_sipp_birthdate)>1940 then m_agecat=7; 
else m_agecat=8; 

if f_race=.Z then do;
  f_nonwhite=.Z;
  f_black=.Z;
end;
else do;
  if f_race>1 then f_nonwhite=1; else f_nonwhite=0;
  if f_race=2 then f_black=1; else f_black=0;
end;

if f_educ_5cat=.Z then do;
  f_educ_d1=.Z;
  f_educ_d3=.Z;
  f_educ_d4=.Z;
  f_educ_d5=.Z;
end;
else do;
  if f_educ_5cat=1 then f_educ_d1=1; else f_educ_d1=0;
  if f_educ_5cat=3 then f_educ_d3=1; else f_educ_d3=0;
  if f_educ_5cat=4 then f_educ_d4=1; else f_educ_d4=0;
  if f_educ_5cat=5 then f_educ_d5=1; else f_educ_d5=0;
end;

if f_total_der_fica_2009=.Z then f_earncat=.Z;
else if f_total_der_fica_2009 le 0 then f_earncat=0;
else if f_total_der_fica_2009 le 10000 then f_earncat=1;
else if f_total_der_fica_2009 le 50000 then f_earncat=2;
else if f_total_der_fica_2009 le 100000 then f_earncat=3;
else if f_total_der_fica_2009 le 300000 then f_earncat=4;
else if f_total_der_fica_2009 le 1000000 then f_earncat=5;
else f_earncat=6;

if f_sipp_birthdate=.Z then f_agecat=.Z; 
else if year(f_sipp_birthdate)>2000 then f_agecat=1; 
else if year(f_sipp_birthdate)>1990 then f_agecat=2; 
else if year(f_sipp_birthdate)>1980 then f_agecat=3; 
else if year(f_sipp_birthdate)>1970 then f_agecat=4; 
else if year(f_sipp_birthdate)>1960 then f_agecat=5; 
else if year(f_sipp_birthdate)>1950 then f_agecat=6; 
else if year(f_sipp_birthdate)>1940 then f_agecat=7; 
else f_agecat=8; 

%mend;


%ENTER_VARIABLE(.);
/*******************************************************************************************************************/


