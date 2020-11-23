/*/
This program is a macro that creates two-way marginal scores.

First, continuous variables are discretized.

Second, a macro is used to create a two-way density similarity 
	score given two variables and two datasets.

Third, a macro is used to loop through all two-way combinations 
	of variables, send these combinations into the two-way 
	density similarity score macro, and save the scores 
	from each combination.

Fourth, the scors are averaged across all variable combinations as 
	the final score.


Inputs:
	1. name of the dataset with synthetic links
	2. name of the dataset with real links
	3. list of variables on which synthetic links are scored
	4. list of variables in 3 that are continuous
	5. number of groups used to discretize continuous vars
	6. prefix name for the first link (e.g., husband/mother)
	7. prefix name for the second link (e.g., wife/child)
	8. name to be used in dataset saving results
	9. output path for saving results
/*/


%macro scoring_macro_links3_samescale(synth_data,input_data,long_data,all_vars,continuous_vars,link1,link2,outputpath,outputpathfigs,outputname);

libname output &outputpath.;
/**************************************************************** 
Create macro to discretize continuous variables, while retaining 
	zero values, structurally missing values, and 
	missing-to-be-replaced values as distint groups
*****************************************************************/
%macro discretize_continuous(vars,inputdata,synthdata,longdata,link1,link2);

data &inputdata._desc;
	set &inputdata.;
run;
data &synthdata._desc;
	set &synthdata.;
run;
data &longdata._desc;
	set &longdata.;
run;

%local i next_i;
	%do i=1 %to %sysfunc(countw(&vars.));
		%let next_i = %scan(&vars.,&i.);

		proc print data=&inputdata._desc (obs=100);
			title "Print Discretize Input Dataset";
		run;
		proc print data=&synthdata._desc (obs=100);
			title "Print Discretize Synth Dataset";
		run;
		
		proc means data=&longdata._desc noprint;
			var &next_i.;
			output out=Percentiles(drop=_:) P10= P20= P30= P40= P50= P60= P70= P80= P90= / autoname;
		run;
		
		data &inputdata._desc;
			if _n_=1 then set Percentiles;
			set &inputdata._desc;
		run;
		data &synthdata._desc;
			if _n_=1 then set Percentiles;
			set &synthdata._desc;
		run;

		data &inputdata._desc(drop=&link1._&next_i._p: &link2._&next_i._p:);
			set &inputdata._desc;
			&link1._&next_i.rank=.;
			if &link1._&next_i.<=&next_i._p10 then &link1._&next_i.rank=1;
			if &link1._&next_i.>&next_i._p10 and &link1._&next_i.<=&next_i._p20 then &link1._&next_i.rank=2;
			if &link1._&next_i.>&next_i._p20 and &link1._&next_i.<=&next_i._p30 then &link1._&next_i.rank=3;
			if &link1._&next_i.>&next_i._p30 and &link1._&next_i.<=&next_i._p40 then &link1._&next_i.rank=4;
			if &link1._&next_i.>&next_i._p40 and &link1._&next_i.<=&next_i._p50 then &link1._&next_i.rank=5;
			if &link1._&next_i.>&next_i._p50 and &link1._&next_i.<=&next_i._p60 then &link1._&next_i.rank=6;
			if &link1._&next_i.>&next_i._p60 and &link1._&next_i.<=&next_i._p70 then &link1._&next_i.rank=7;
			if &link1._&next_i.>&next_i._p70 and &link1._&next_i.<=&next_i._p80 then &link1._&next_i.rank=8;
			if &link1._&next_i.>&next_i._p80 and &link1._&next_i.<=&next_i._p90 then &link1._&next_i.rank=9;
			if &link1._&next_i.>&next_i._p90 then &link1._&next_i.rank=10;
			if &link1._&next_i.=. then &link1._&next_i.rank=0;
			drop &link1._&next_i.;
			rename &link1._&next_i.rank=&link1._&next_i.;
			&link2._&next_i.rank=.;
			if &link2._&next_i.<=&next_i._p10 then &link2._&next_i.rank=1;
			if &link2._&next_i.>&next_i._p10 and &link2._&next_i.<=&next_i._p20 then &link2._&next_i.rank=2;
			if &link2._&next_i.>&next_i._p20 and &link2._&next_i.<=&next_i._p30 then &link2._&next_i.rank=3;
			if &link2._&next_i.>&next_i._p30 and &link2._&next_i.<=&next_i._p40 then &link2._&next_i.rank=4;
			if &link2._&next_i.>&next_i._p40 and &link2._&next_i.<=&next_i._p50 then &link2._&next_i.rank=5;
			if &link2._&next_i.>&next_i._p50 and &link2._&next_i.<=&next_i._p60 then &link2._&next_i.rank=6;
			if &link2._&next_i.>&next_i._p60 and &link2._&next_i.<=&next_i._p70 then &link2._&next_i.rank=7;
			if &link2._&next_i.>&next_i._p70 and &link2._&next_i.<=&next_i._p80 then &link2._&next_i.rank=8;
			if &link2._&next_i.>&next_i._p80 and &link2._&next_i.<=&next_i._p90 then &link2._&next_i.rank=9;
			if &link2._&next_i.>&next_i._p90 then &link2._&next_i.rank=10;
			if &link2._&next_i.=. then &link2._&next_i.rank=0;
			drop &link2._&next_i.;
			rename &link2._&next_i.rank=&link2._&next_i.;
		run;
		data &synthdata._desc(drop=&link1._&next_i._p: &link2._&next_i._p:);
			set &synthdata._desc;
			&link1._&next_i.rank=.;
			if &link1._&next_i.<=&next_i._p10 then &link1._&next_i.rank=1;
			if &link1._&next_i.>&next_i._p10 and &link1._&next_i.<=&next_i._p20 then &link1._&next_i.rank=2;
			if &link1._&next_i.>&next_i._p20 and &link1._&next_i.<=&next_i._p30 then &link1._&next_i.rank=3;
			if &link1._&next_i.>&next_i._p30 and &link1._&next_i.<=&next_i._p40 then &link1._&next_i.rank=4;
			if &link1._&next_i.>&next_i._p40 and &link1._&next_i.<=&next_i._p50 then &link1._&next_i.rank=5;
			if &link1._&next_i.>&next_i._p50 and &link1._&next_i.<=&next_i._p60 then &link1._&next_i.rank=6;
			if &link1._&next_i.>&next_i._p60 and &link1._&next_i.<=&next_i._p70 then &link1._&next_i.rank=7;
			if &link1._&next_i.>&next_i._p70 and &link1._&next_i.<=&next_i._p80 then &link1._&next_i.rank=8;
			if &link1._&next_i.>&next_i._p80 and &link1._&next_i.<=&next_i._p90 then &link1._&next_i.rank=9;
			if &link1._&next_i.>&next_i._p90 then &link1._&next_i.rank=10;
			if &link1._&next_i.=. then &link1._&next_i.rank=0;
			drop &link1._&next_i.;
			rename &link1._&next_i.rank=&link1._&next_i.;
			&link2._&next_i.rank=.;
			if &link2._&next_i.<=&next_i._p10 then &link2._&next_i.rank=1;
			if &link2._&next_i.>&next_i._p10 and &link2._&next_i.<=&next_i._p20 then &link2._&next_i.rank=2;
			if &link2._&next_i.>&next_i._p20 and &link2._&next_i.<=&next_i._p30 then &link2._&next_i.rank=3;
			if &link2._&next_i.>&next_i._p30 and &link2._&next_i.<=&next_i._p40 then &link2._&next_i.rank=4;
			if &link2._&next_i.>&next_i._p40 and &link2._&next_i.<=&next_i._p50 then &link2._&next_i.rank=5;
			if &link2._&next_i.>&next_i._p50 and &link2._&next_i.<=&next_i._p60 then &link2._&next_i.rank=6;
			if &link2._&next_i.>&next_i._p60 and &link2._&next_i.<=&next_i._p70 then &link2._&next_i.rank=7;
			if &link2._&next_i.>&next_i._p70 and &link2._&next_i.<=&next_i._p80 then &link2._&next_i.rank=8;
			if &link2._&next_i.>&next_i._p80 and &link2._&next_i.<=&next_i._p90 then &link2._&next_i.rank=9;
			if &link2._&next_i.>&next_i._p90 then &link2._&next_i.rank=10;
			if &link2._&next_i.=. then &link2._&next_i.rank=0;
			drop &link2._&next_i.;
			rename &link2._&next_i.rank=&link2._&next_i.;
		run;
		
		proc print data=&inputdata._desc (obs=100);
			title "Print Discretize Input_Out Dataset";
		run;
		proc print data=&synthdata._desc (obs=100);
			title "Print Discretize Synth_Out Dataset";
		run;
	%end;
%mend discretize_continuous;

*discretize the three continuous variables involved in the syn links dataset;
%discretize_continuous(&continuous_vars.,&input_data.,&synth_data.,&long_data.,&link1.,&link2.);




/***************************************************************
Create macro to score the two-way density similarity for two 
	given variables and two given datasets.
***************************************************************/
%macro score(var1,var2,input,synth,outputname);
proc sort data=&input. out=&input;
	by &var1. &var2.;
run;
proc summary data=&input.;
	var personid;
	by &var1. &var2.;
	output out=density_input n=n_input;
run;
proc sql;
	create table density_input as 
	select &var1., &var2., n_input, sum(n_input) as n_input_total
	from density_input;
quit;
data density_input;
	set density_input;
	density_input=n_input/n_input_total;
run;

proc sort data=&synth. out=&synth;
	by &var1. &var2.;
run;
proc summary data=&synth.;
	var personid;
	by &var1. &var2.;
	output out=density_synth n=n_synth;
run;
proc sql;
	create table density_synth as 
	select &var1., &var2., n_synth, sum(n_synth) as n_synth_total
	from density_synth;
quit;
data density_synth;
	set density_synth;
	density_synth=n_synth/n_synth_total;
run;

proc sort data=density_input out=density_input;
	by &var1. &var2.;
run;
proc sort data=density_synth out=density_synth;
	by &var1. &var2.;
run;

data merged;
	merge density_input(in=a) density_synth(in=b);
	by &var1. &var2.;
run;

data merged;
	set merged;
	if density_synth=. then density_synth=0;
	if density_input=. then density_input=0;
*	if &var1.=c1_sipp_birthdate and &var2.=c2_sipp_birthdate then 
*		do;
*			if n_synth<3 and n_synth^=. then density_synth=.;
*			if n_input<3 and n_input^=. then density_input=.;
*		end;
*	else 
*		do;
*			if n_synth<10 and n_synth^=. then density_synth=.;
*			if n_input<10 and n_input^=. then density_input=.;
*		end;

	density_diff = density_synth-density_input;
	abs_density_diff = abs(density_diff);
run;
proc print data=merged (obs=100);
	title "Print Scored Dataset All Dimensions - var1=&var1. var2=&var2.";
run;


proc template;
define statgraph heatmapparm;
  begingraph;
    rangeattrmap name="ThreeColor";
	*range NEGMAXABS-MAXABS / rangecolormodel=ThreeColorRamp;
	range -0.06-0.06 / rangecolormodel=ThreeColorRamp;
    endrangeattrmap;
    rangeattrvar attrvar=rangevar var=density_diff attrmap="ThreeColor";
    layout overlay;
      heatmapparm x=&var1. y=&var2. colorresponse=rangevar /
	name="heatmapparm" xbinaxis=false ybinaxis=false;
      continuouslegend "heatmapparm" / location=outside valign=bottom;
    endlayout;
  endgraph;
end;
run;

/*
ods graphics / reset=index imagename="Heatmap_&outputname._&var1._&var2." imagefmt=png;
ods listing gpath=&outputpathfigs;
call HeatmapCont(merged) scale="Col"
	xvalues=&var1. yvalues=&var2.
	colorramp="ThreeColor" range={-0.1,0.1}
	legendtitle = "Density Difference" title="Heatmap x-&var1. y-&var2.";
*/

ods graphics / reset=index imagename="Heatmap_&outputname._&var1._&var2." imagefmt=png;
ods listing gpath=&outputpathfigs;
proc sgrender data=merged template=heatmapparm;
run;

/*
ods graphics / reset=index imagename="HeatMap_&outputname._&var1.&var2." imagefmt=png;
ods listing gpath=&outputpathfigs;
proc sgrender data=merged template=heatmap;
run;
*/

proc summary data=merged;
	var abs_density_diff;
	output out=finalscore sum=score;
run;

data finalscore;
set finalscore;
	length var1 $29;
	length var2 $29;
	var1="&var1.";
	var2="&var2.";

%mend score;


/***************************************************************
Create macro to loop through each combination of two variables,
	send them into the scoring macro, and store resulting 
	scores from all combinations
***************************************************************/
%macro twoway(list1,list2,link1,link2);
%local i j next_i next_j;
%let n=0;
	%do i=1 %to %sysfunc(countw(&list1.));
		%let next_i = %scan(&list1.,&i.);
		%do j=1 %to %sysfunc(countw(&list2.));
			%let next_j = %scan(&list2.,&j.);
	
				%let n=%eval(&n+1);
				%score(&link1._&next_i.,&link2._&next_j.,&input_data._desc,&synth_data._desc,&outputname);
				
				%if &n=1 %then %do;
					data scores;
						set finalscore;
					run;
				%end;
				%if &n>1 %then %do;
					data scores;
						set scores finalscore;
					run;
				%end;

		%end;
	%end;
%mend twoway;

*loop through all two-way combinations of variables;
%twoway(&all_vars.,&all_vars.,&link1.,&link2.);



/****************************************************************
Average the scores across all two-way variable combinations and 
	print the final score.
****************************************************************/
proc summary data=scores;
	var score;
	output out=output.score_final_&outputname mean=mean2way_score;
run;
proc print data=output.score_final_&outputname;
	title "Print Final Mean Two-Way Marginal Score";
run;


/***************************************************************
Save the each of the two-way scores, too
***************************************************************/
proc sort data=scores out=output.scores_all2way_&outputname;
	by score;
run;

%mend scoring_macro_links3;


