/*
This program prepares the synthetic linkages data to go into the scoring macro,
	sends them into the macro, and then uses the scoring results to create 
	some additional output.

Preparing the data to go into the scoring macro involves reshaping the synthetic and 
	real input files to be a wide format, with the husband and wife variables on 
	the same line.
*/

libname here "./";

%let outputpath="./";
%let outputpathfigs="./heatmaps";
%let synth= "../../synthesize/persons";
%let input= "../../build";
%let figures= "./heatmaps";
%include "scoring_macro_links3_samescale.sas";


%let vars=
	sipp_birthdate; 
%let continuous_vars=
	sipp_birthdate;

libname synth &synth.;
libname input &input.;

data longinput;
set input.person_file(where=(linked_child=1 or linked_mom=1));

data person_file;
set input.person_file;
	log_totderfica_2009=log(total_der_fica_2009);
	log_totderfica_2010=log(total_der_fica_2010);
run;
data syn_person1;
set synth.syn_person1;
	log_totderfica_2009=log(total_der_fica_2009);
	log_totderfica_2010=log(total_der_fica_2010);
run;
data syn_person2;
set synth.syn_person2;
	log_totderfica_2009=log(total_der_fica_2009);
	log_totderfica_2010=log(total_der_fica_2010);
run;
data syn_person3;
set synth.syn_person3;
	log_totderfica_2009=log(total_der_fica_2009);
	log_totderfica_2010=log(total_der_fica_2010);
run;
data syn_person4;
set synth.syn_person4;
	log_totderfica_2009=log(total_der_fica_2009);
	log_totderfica_2010=log(total_der_fica_2010);
run;





/********************************************************************
 Reshape datasets to put mom and child variables in wide format 
********************************************************************/
%macro add_prefix(data);
data &data.c;
	set &data.(keep=linked_child personid mom_personid &vars.
	where=(linked_child=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		data &data.c;
		set &data.c;
			rename &next_i=c_&next_i;
		run;
	%end;

data &data.m;
	set &data.(keep=linked_mom personid &vars.
	where=(linked_mom=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		data &data.m;
		set &data.m;
			rename &next_i=m_&next_i;
			rename personid=mom_personid;
		run;
	%end;

proc sort data=&data.c out=&data.c;
	by mom_personid;
run;
proc sort data=&data.m out=&data.m;
	by mom_personid;
run;
data &data.;
	merge &data.c(in=a) &data.m(in=b);
	by mom_personid;
	if a and b;
run;

%mend add_prefix;

%add_prefix(syn_person1);
%add_prefix(syn_person2);
%add_prefix(syn_person3);
%add_prefix(syn_person4);
%add_prefix(person_file);

	
/*******************************************************************
Split the input datasets into two halves, for a baseline check based 
on sampling error only
*******************************************************************/
proc surveyselect data=person_file 
	out=person_file_samplea
	method=SRS
	samprate=0.50;
run;
proc surveyselect data=person_file 
	out=person_file_sampleb
	method=SRS
	samprate=0.50;
run;
proc surveyselect data=person_file 
	out=person_file_samplec
	method=SRS
	samprate=0.50;
run;



/********************************************************************
Send datasets into the macro to be scored 
********************************************************************/
%scoring_macro_links3_samescale(syn_person1,person_file,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,synp1_kid2);
%scoring_macro_links3_samescale(syn_person2,person_file,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,synp2_kid2);
%scoring_macro_links3_samescale(syn_person3,person_file,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,synp3_kid2);
%scoring_macro_links3_samescale(syn_person4,person_file,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,synp4_kid2);

%scoring_macro_links3_samescale(person_file_samplea,person_file,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,baseline_kid2);
%scoring_macro_links3_samescale(person_file_sampleb,person_file_samplec,longinput,&vars.,&continuous_vars.,c,m,&outputpath.,&outputpathfigs.,twosamples_kid2);



