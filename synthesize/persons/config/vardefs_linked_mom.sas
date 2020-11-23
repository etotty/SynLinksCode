
/*******************************************************************************************************************/
/*** SPEC WRITTEN BY: <name>, <branch>-<division> ***/


*** BASIC INFO;
%let variable=linked_mom; /* name of sas variable on input file to be imputed */
%let level=1; /* will help determine order of imputation */
%let ever_out_of_universe=1; /* =1 if &variable. is ever out of universe, =0 otherwise */
%let universe_determinants=linked_couple; /* list of variables used to determine when &variable. is in universe */
%macro universe_condition;
/********************************************************
  INSIDE THE %UNIVERSE_CONDTION MACRO,
  WRITE CODE AS IF INSIDE A SAS IF-THEN CLAUSE
  THAT SPECIFIES WHEN &VARIABLE. IS IN UNIVERSE.

  IF &EVER_OUT_OF_UNIVERSE.=1 THEN THE FOLLOWING
  CODE SHOULD WORK WITHOUT ERROR IN A SAS DATA STEP:
  
  if %universe_condition then do;
    put "The variable, &variable., is in universe!";
  end;
********************************************************/
1
%mend;


*** STRATIFICATION;
%let num_lists=3; /* number of stratification lists provided from finest to coarsest */
/* next: list of numerical, categorical variables to stratify data before regression/bootstrap */
%let stratifiers1=male linked_child hhh_flag;
%let stratifiers2=male linked_child;
%let stratifiers3=linked_child;
/*******
WARNING: COARSEST LIST (&&stratifiers&num_lists..) SHOULD NOT HAVE ANY CELLS
 WHERE THERE ARE VALUES IN NEED OF IMPUTATION AND THERE ARE NOT ENOUGH OBSERVATIONS
 WITHOUT NEED OF IMPUTATION TO ESTIMATE REQUESTED MODEL
 REGRESSION MIN CELL SIZE=100
*******/


*** CONSTRAINTS;
/* next: specify variables that contain minimum and maximum values for imputed values for each record.
     if there is no variable constraining the imputed value, leave blank.
     if the constraining variable needs to be calculated in a DATA STEP before imputation,
       use the inputs macro variable and the calculate_constraints macro to define */
%let minimum_variable=;
%let maximum_variable=;
/* next: list of variables on the input file needed to calculate constraints
     if &minimum_variable. is a variable on the input file then include it in the &inputs. list
     if &maximum_variable. is a variable on the input file then include it in the &inputs. list
     leave blank if no constraints or if no variables from input file are needed to calculate constraints
       (eg. a trivial constraint like: &minimum_variable.=minvar and minvar=0) */
%let inputs=;
%macro calculate_constraints;
/********************************************************
  INSIDE THE %CALCULATE_CONSTRAINTS MACRO,
  WRITE SAS CODE THAT CREATES
  &MINIMUM_VARIABLE. AND/OR &MAXIMUM_VARIABLE
  FROM &INPUTS. AS THOUGH THIS CODE WAS INSIDE A SAS DATA STEP 
********************************************************/

%mend;


*** REGRESSORS;
/* next: list of variables that will ever be used as regressors, as they stand, in modeling &variable. */
%let regressors_notransform=
hhh_flag linked_couple linked_child
male nonwhite black hispanic foreign_born
educ_d1 educ_d3 educ_d4 educ_d5
;
/* next: list of variables that will ever be used as regressors in modeling &variable.
 after undergoing a non-parametric transform to an approximate standard normal */
%let regressors_transform=
sipp_birthdate time_arrive_usa total_der_fica_2009
;
/* next: list of interactions.
     Only use variables from the regressor lists.
     Write interaction using SAS syntax with NO SPACES. eg: (var1**2)*var2
     Put a space between each separate interaction term. eg: (var1**2)*var2 var3*var4 */
%let interactions=
sipp_birthdate**2 sipp_birthdate*total_der_fica_2009 total_der_fica_2009**2
;


*** POST-IMPUTATION;
/* next: specify any post-imputation edits needed directly after imputation. 
     This code will be run on full sample (not just where &variable. is in-universe).
     If not careful, one can make un-recoverable changes to the working, synthetic file. */
%macro post_impute;
/********************************************************
  INSIDE THE %POST_IMPUTE MACRO,
  WRITE SAS CODE THAT PERFORMS EDITS AFTER IMPUTATION
  AS THOUGH THIS CODE WAS INSIDE A SAS DATA STEP 
********************************************************/

%mend;
%let drop_vars=; /* a list of any variables defined in %post_impute that should not be kept on file */
%let pi_outputs=; /* a list of any variables defined in %post_impute that should be kept, and are not defined anywhere else */


%ENTER_VARIABLE(2);
/*******************************************************************************************************************/


