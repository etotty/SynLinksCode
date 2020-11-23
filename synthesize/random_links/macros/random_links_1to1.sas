
/**************************************************************
IMPORTANT: fastbb.sas must be included in program that calls this macro!

This macro creates random links between records in IMP_AFILE
and records in IMP_BFILE according to the covariate
relationships implied by known linkages between records in
EST_AFILE and EST_BFILE. Those known linkages are stored 
in EST_XWALK. This is for cases where there are one-to-one
matches between AIDs and BIDs.

The EST_AFILE must have the same variable names as IMP_AFILE,
and EST_BFILE must have the same variable names as IMP_BFILE.
Moreover, the set of variable names on the AFILEs must be
mutually exclusive from the set of variable names on the BFILEs.

AID should store a unique record ID on the AFILEs.
BID should store a unique record ID on the BFILEs.

AVARS is the set of variables on the AFILEs which this
macro attempts to preserve covariate properties with
a BVARS, set of variables on the BFILEs.

EST_XWALK contains only pairs of AID and BID. There may
be more than one AID for a single BID, but there MUST NOT
be more than one BID for a single AID.

If you wish to allow more than one AID per BID, then you should
choose to sample with replacement (REPLACEMENT=1), otherwise,
if you only want to allow one-to-one linkages, you should sample
without replacement (REPLACEMENT=0).

If (and only if) you sample with replacement, you may choose
to limit the number of times the same BID can be chosen by
setting LINK_LIMIT_VAR equal to the name of a variable on
IMP_BFILE which contatins that limit for each BID.

BYGROUP will assign BID links to AID only where the BYGROUP
variable is the same for both AID and BID. This variable
must be numeric.
**************************************************************/

%macro random_links(
  est_afile, est_bfile, est_xwalk,
  imp_afile, imp_bfile, imp_xwalk,
  aid, bid, avars, bvars,
  replacement, link_limit_var=, penalty_var=, penalty_cond=, seed=0, bygroup=);

  %local est_afile est_bfile est_xwalk imp_afile imp_bfile imp_xwalk aid bid avars bvarss
         replacement link_limit_var penalty_var penalty_cond bygroup;
  %local i tmp limit_flag;

  proc sort data=&est_afile. out=est_afile;
    by &aid.;
  run;
  proc sort data=&est_xwalk. out=est_xwalk;
    by &aid.;
  run;
  data estimation_set;
    merge est_afile (in=aa) est_xwalk;
    by &aid.;
    if aa;
  run;
  proc sort data=estimation_set;
    by &bid.;
  run;
  proc sort data=&est_bfile. out=est_bfile;
    by &bid.;
  run;
  data estimation_set;
    merge est_bfile (in=bb) estimation_set;
    by &bid.;
    if bb;
  run;
  %fastbb(estimation_set,bb_estimation_set,&avars. &bvars.,seed=&seed.);
  proc corr data=bb_estimation_set outp=ab_covmat cov noprint;
    var &avars. &bvars.;
  run;
  data imp_afile;
    set &imp_afile. end=lastobs;
    retain seed &seed.;
    call ranuni(seed,_tmpuni_);
    if lastobs then call symput("seed",compress(put(seed,12.)));
  run;
  proc sort data=imp_afile;
    by _tmpuni_;
  run;
  proc iml;
    use ab_covmat;
    read all var{&avars.} where(_type_="COV") into sigma_left;
    read all var{&bvars.} where(_type_="COV") into sigma_right;
    read all var{&avars.} where(_type_="CORR") into rho_left;
    read all var{&bvars.} where(_type_="CORR") into rho_right;
    read all var{&avars.} where(_type_="MEAN") into mu1;
    read all var{&bvars.} where(_type_="MEAN") into mu2;
    na=ncol(sigma_left);
    nb=ncol(sigma_right);
    sigma11=sigma_left[1:na,];
    sigma21=sigma_left[na+1:na+nb,];
    sigma22=sigma_right[na+1:na+nb,];
    sigma12=sigma_right[1:na,];
    sigma=sigma_left || sigma_right;
    sigma_inv=inv(sigma);
    sigma11_inv=inv(sigma11);
    * Use standardized Euclidean distance for nearest neighbor match;
    *dist_sigma_inv=inv(diag(sigma));
    * Use Mahalanobis distance for nearest neighbor match;
    dist_sigma_inv=sigma_inv;

    use estimation_set;
    read all var{&avars.} into orig_ax;
    read all var{&bvars.} into orig_bx;
    orig_n=nrow(orig_ax);
    orig_distfrommean=j(orig_n,1,.);
    bmu = t(t(shape(mu2,orig_n,nb)) + sigma21*(sigma11_inv)*(t(orig_ax)-t(shape(mu1,orig_n,na))));
    do i=1 to orig_n;
      orig_distfrommean[i]=((orig_ax[i,] || bmu[i,])-(orig_ax[i,] || orig_bx[i,]))*dist_sigma_inv*t((orig_ax[i,] || bmu[i,])-(orig_ax[i,] || orig_bx[i,]));
    end;
    varnames={distfrommean};
    create _origdist_ from orig_distfrommean[colname=varnames];
    append from orig_distfrommean;

    use imp_afile;
    read all var{&avars.} into full_ax;
    read all var{&aid.} into full_aid;
    %if "&bygroup." ~= "" %then %do;
      read all var{&bygroup.} into bygroup_a;
    %end;
    %else %do;
      bygroup_a=j(nrow(full_ax),1,1);
    %end;
    %if "&penalty_var." ~= "" %then %do;
      read all var{&penalty_var.} into penalty_var_a;
    %end;
    use &imp_bfile.;
    read all var{&bvars.} into full_bx;
    read all var{&bid.} into full_bid;
    %if "&link_limit_var." ~= "" %then %do;
      %let limit_flag=1;
      read all var{&link_limit_var.} into full_link_limit;
    %end;
    %else %let limit_flag=0;
    %if "&bygroup." ~= "" %then %do;
      read all var{&bygroup.} into bygroup_b;
    %end;
    %else %do;
      bygroup_b=j(nrow(full_bx),1,1);
    %end;
    max_bygroup=max(bygroup_a);
    %if "&penalty_var." ~= "" %then %do;
      read all var{&penalty_var.} into penalty_var_b;
    %end;

    stop_bygroup=0;
    count_bygroup=0;
    do until(stop_bygroup=1);
      count_bygroup=count_bygroup+1;
      tmp_min_bygroup=min(bygroup_a);
      tmp_bygroup_a=loc(bygroup_a=tmp_min_bygroup);
      ax=full_ax[tmp_bygroup_a,];
      anobs=nrow(ax);
      aid=full_aid[tmp_bygroup_a,];
      %if "&penalty_var." ~= "" %then %do;
        pva=penalty_var_a[tmp_bygroup_a,];
      %end;
      if loc(bygroup_b=tmp_min_bygroup) then do;
*******************************************************************;
        tmp_bygroup_b=loc(bygroup_b=tmp_min_bygroup);
        bx=full_bx[tmp_bygroup_b,];
        bnobs=nrow(bx);
        bid=full_bid[tmp_bygroup_b,];
        %if "&link_limit_var." ~= "" %then %do;
          link_limit=full_link_limit[tmp_bygroup_b,];
        %end;
        %if "&penalty_var." ~= "" %then %do;
          pvb=penalty_var_b[tmp_bygroup_b,];
        %end;

        bmu_given_ax = t(t(shape(mu2,anobs,nb)) + sigma21*(sigma11_inv)*(t(ax)-t(shape(mu1,anobs,na))));
        bsigma_given_ax = sigma22 - (sigma21*(sigma11_inv)*sigma12);

        imputed_link=aid || j(anobs,4,.);
        call randseed(&seed.);
        noise=randnormal(anobs,j(1,nb,0),(bnobs/bnobs)*bsigma_given_ax);
        %if &replacement.=1 %then %do;
          %if &limit_flag.=1 %then %do;
            *** sample with replacement until we reach limit;
            assigned=j(bnobs,1,0);
            numlinks=j(bnobs,1,0);
            do i=1 to anobs;
              if min(assigned)=0 then do;
                distances=j(bnobs-sum(assigned),1,.);
                distfrommean=j(bnobs-sum(assigned),1,.);
                tmp_bx=bmu_given_ax[i,]+noise[i,];
                tmp_assigned=loc(assigned=0);
                do tmpj=1 to bnobs-sum(assigned);
                  j=tmp_assigned[tmpj];
                  distances[tmpj]=((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]));
                  distfrommean[tmpj]=((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]));
                  %if "&penalty_var." ~= "" %then %do;
                    if abs(pva[i]-pvb[j])>&penalty_cond.
                    then distances[tmpj]=distances[tmpj]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                  %end;
                end;
                tmp_mins=loc(distances=min(distances));
                call randgen(tmp_uni,'UNIFORM');
                tmp_j=tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
                imputed_link[i,2] = bid[tmp_j];
                imputed_link[i,3] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
                imputed_link[i,5] = distfrommean[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
                numlinks[tmp_j] = numlinks[tmp_j] + 1;
                if numlinks[tmp_j] >= link_limit[tmp_j] then assigned[tmp_j] = 1;
              end;
              imputed_link[i,4]=i;
            end;
          %end;
          %else %do;
            *** sample with replacement;
            do i=1 to anobs;
              distances=j(bnobs,1,.);
              distfrommean=j(bnobs,1,.);
              tmp_bx=bmu_given_ax[i,]+noise[i,];
              do j=1 to bnobs;
                distances[j]=((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]));
                distfrommean[j]=((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]));
                %if "&penalty_var." ~= "" %then %do;
                  if abs(pva[i]-pvb[j])>&penalty_cond.
                  then distances[j]=distances[j]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                %end;
              end;
              tmp_mins=loc(distances=min(distances));
              call randgen(tmp_uni,'UNIFORM');
              imputed_link[i,2]=bid[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              imputed_link[i,3] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              imputed_link[i,5] = distfrommean[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              imputed_link[i,4]=i;
            end;
          %end;
        %end;
        %else %do;
          *** sample without replacement;
          assigned=j(bnobs,1,0);
          do i=1 to anobs;
            if min(assigned)=0 then do;
              distances=j(bnobs-sum(assigned),1,.);
              distfrommean=j(bnobs-sum(assigned),1,.);
              tmp_bx=bmu_given_ax[i,]+noise[i,];
              tmp_assigned=loc(assigned=0);
              do tmpj=1 to bnobs-sum(assigned);
                j=tmp_assigned[tmpj];
                distances[tmpj]=((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || tmp_bx)-(ax[i,] || bx[j,]));
                distfrommean[tmpj]=((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]))*dist_sigma_inv*t((ax[i,] || bmu_given_ax[i,])-(ax[i,] || bx[j,]));
                %if "&penalty_var." ~= "" %then %do;
                  if abs(pva[i]-pvb[j])>&penalty_cond.
                  then distances[tmpj]=distances[tmpj]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                %end;
              end;
              tmp_mins=loc(distances=min(distances));
              call randgen(tmp_uni,'UNIFORM');
              imputed_link[i,2]=bid[ tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ] ];
              imputed_link[i,3] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              imputed_link[i,5] = distfrommean[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              assigned[ tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ] ] = 1;
            end;
            imputed_link[i,4]=i;
          end;
        %end;

        %if "&bygroup." ~= "" %then %do;
          imputed_link=imputed_link || bygroup_a[tmp_bygroup_a,];
        %end;
        if count_bygroup=1 then full_imputed_link=imputed_link;
        else full_imputed_link=full_imputed_link // imputed_link;
*******************************************************************;
      end;
      bygroup_a[tmp_bygroup_a,]=j(anobs,1,max_bygroup+1);
      if min(bygroup_a)=max_bygroup+1 then stop_bygroup=1;
    end;

    varnames={&aid. &bid. distance order distfrommean &bygroup.};
    create &imp_xwalk. from full_imputed_link[colname=varnames];
    append from full_imputed_link;
  quit;
  proc sort data=&imp_xwalk.;
    by &aid. &bid.;
  run;

  data _null_;
    seed=&seed.;
    call ranuni(seed,x1);
    call ranuni(seed,x2);
    call ranuni(seed,x3);
    a1=min(of x1-x3);
    a2=median(of x1-x3);
    a3=max(of x1-x3);
    current_seed=ceil((a2-a1)*2147483646/(a3-a1));
    call symput("seed",compress(put(current_seed,12.)));
  run;

%mend;





