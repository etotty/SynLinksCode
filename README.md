# SynLinksCode
code for replicating Benedetto and Totty (2020) synthetic links creation and evaluation


This repository includes the code used to build, synthesize, and evaluate the linkages in "Synthesizing Familial Linkages for Privacy in Microdata" (Benedetto and Totty, 2020). 

The paper uses data from the Census Bureau Gold Standard File (GSF). This data is confidential. However, external researchers may access it by applying to use the SIPP Synthetic Beta (SSB) data. The SSB is a fully synthetic version of the GSF. Researchers can build their code on the SSB, then submit their code for validation on the GSF. Additional information can be found here: https://www.census.gov/programs-surveys/sipp/guidance/sipp-synthetic-beta-data-product.html.



Summary and instructions for the code:
-----
The code is divided into three subdirectories:

1. build - code used to build the sample of analysis
2. synthesize - code used to synthesize the person, couple, and links information
3. evaluate - code used to evaluate the quality of the synthetic links


RUN THE FOLLOWING PROGRAMS IN THE FOLLOWING ORDER TO REPLICATE THE ANALYSIS
-----
build

1. build_indat - creates an extract of the GSF to use for analysis, re-formats the data, 
	and creates new variables. This file needs to be edited to point to the raw 
	input data.
2. make_couples - subsets to couples from that extract, re-formats the data, and 
	creates new variables.


-----
synthesize

3. prog01-prog02 in couples/ - creates datasets of synthetic couples
4. prog01-prog02 in persons/ - creates datasets of synthetic persons
5. synlinks0-synlinks2 in random_links/ - creates crosswalks for new synthetic links
6. update_links-update_links2 in random_links/ - creates datasets with synthetic links


-----
evaluate

7. check_links2-check_links4 - checks distributional comparisions between original and 
	synthetic data
8. pair_recreation - checks percent of original links re-created in synthetic links
9. input2royston - prepares data for Royston multivariate normality test
10. mv_normal_matlab_new - performs the Royston test
11. build_comparison-build_comparison2 in BKPgraphs/ - prepares data for share of 
	couples earnings graphs (needs to be edited to point to v6 and v7 GSF data)
12. export in BKPgraphs/ - exports SAS data to Stata for share of couples earnings graphs
13. revision* in BKPgraphs/ - creates share of couples earnings graphs for various datasets
14. evaluate3* in Heatmaps/ - creates the two-way marginal results and heatmaps
