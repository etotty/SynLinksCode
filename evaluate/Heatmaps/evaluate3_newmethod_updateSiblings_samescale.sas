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
set input.person_file(where=(linked_child=1));
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
 Reshape datasets to put sibling variables in wide format 
********************************************************************/
%macro add_prefix(data);
data &data.c1;
	set &data.(keep=linked_child personid mom_personid &vars.
	where=(linked_child=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		data &data.c1;
		set &data.c1;
			rename &next_i=c1_&next_i;
		run;
	%end;

data &data.c2;
	set &data.(keep=linked_child personid mom_personid &vars.
	where=(linked_child=1));
run;
%local i next_i;
	%do i=1 %to %sysfunc(countw(personid &vars.));
		%let next_i = %scan(personid &vars.,&i.);

		data &data.c2;
		set &data.c2;
			rename &next_i=c2_&next_i;
		run;
	%end;

proc sort data=&data.c1 out=&data.c1;
	by mom_personid;
run;
proc sort data=&data.c2 out=&data.c2;
	by mom_personid;
run;

*data &data.;
*	merge &data.c1(in=a) &data.c2(in=b);
*	by mom_personid;
*run;
proc sql;
  create table &data. as 
	select a.*, b.* 
	from &data.c1 a inner join &data.c2 b 
	on a.mom_personid=b.mom_personid;
  quit;
run;


proc print data=&data.(obs=20);
run;

data &data.;
set &data.;
	cid_sum=personid+c2_personid;
	if personid=c2_personid then delete;
	if mom_personid=. then delete;
run;

*proc sort data=&data. out=&data. nodupkey;
*	by mom_personid cid_sum;
*run;
data &data.;
set &data.;
	if c1_sipp_birthdate>c2_sipp_birthdate then delete;
run;

proc print data=&data.(obs=20);
run;

proc means data=&data.;
var c1_sipp_birthdate c2_sipp_birthdate;
output out=ptiles p10= p20= p30= p40= p50= p60= p70= p80= p90= / autoname;
title '&data. child birthdate';
run;

proc print data=ptiles;
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
%scoring_macro_links3_samescale(syn_person1,person_file,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,synp1_sib2);
%scoring_macro_links3_samescale(syn_person2,person_file,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,synp2_sib2);
%scoring_macro_links3_samescale(syn_person3,person_file,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,synp3_sib2);
%scoring_macro_links3_samescale(syn_person4,person_file,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,synp4_sib2);

%scoring_macro_links3_samescale(person_file_samplea,person_file,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,baseline_sib2);
%scoring_macro_links3_samescale(person_file_sampleb,person_file_samplec,longinput,&vars.,&continuous_vars.,c1,c2,&outputpath.,&outputpathfigs.,twosamples_sib2);



