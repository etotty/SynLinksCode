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
%let figures= "./";
%include "scoring_macro_links3_samescale.sas";


%let vars=
	total_der_fica_2009 sipp_birthdate; 
%let continuous_vars=
	total_der_fica_2009 sipp_birthdate;


libname synth &synth.;
libname input &input.;

data longinput;
set input.person_file(where=(linked_couple=1));
run;

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
 Reshape datasets to put husband and wife variables in wide format 
********************************************************************/
%macro add_prefix(data);
data &data.h;
	set &data.(keep=male linked_couple personid spouse_personid &vars.
	where=(male=1 and linked_couple=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		data &data.h;
		set &data.h;
			rename &next_i=m_&next_i;
		run;
	%end;

data &data.w;
	set &data.(keep=male linked_couple personid &vars.
	where=(male=0 and linked_couple=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		data &data.w;
		set &data.w;
			rename &next_i=f_&next_i;
			rename personid=spouse_personid;
		run;
	%end;

proc sort data=&data.h out=&data.h;
	by spouse_personid;
run;
proc sort data=&data.w out=&data.w;
	by spouse_personid;
run;
data &data.;
	merge &data.h(in=a) &data.w(in=b);
	by spouse_personid;
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
%scoring_macro_links3_samescale(syn_person1,person_file,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,synp1_spous2);
%scoring_macro_links3_samescale(syn_person2,person_file,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,synp2_spous2);
%scoring_macro_links3_samescale(syn_person3,person_file,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,synp3_spous2);
%scoring_macro_links3_samescale(syn_person4,person_file,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,synp4_spous2);

%scoring_macro_links3_samescale(person_file_samplea,person_file,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,baseline_spous2);
%scoring_macro_links3_samescale(person_file_sampleb,person_file_samplec,longinput,&vars.,&continuous_vars.,m,f,&outputpath.,&outputpathfigs.,twosamples_spous2);



