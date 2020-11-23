
/**************************************************************
IMPORTANT: fastbb.sas must be included in program that calles this macro!

This macro creates random links between records in IMP_AFILE
and records in IMP_BFILE according to the covariate
relationships implied by known linkages between records in
EST_AFILE and EST_BFILE. Those known linkages are stored 
in EST_XWALK. This is for cases where there can be one-to-many
matches between AIDs and BIDs, and the covariance between BVARS
amongst BIDs linked to the same AID is the same across all AIDs.

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
  aid, bid, avars, bvars, numlinks_var,
  replacement, bsortvar=none, link_limit_var=, penalty_var=, penalty_cond=, seed=0, bygroup=);

  %local est_afile est_bfile est_xwalk imp_afile imp_bfile imp_xwalk aid numlinks_var bid avars bvars
         bsortvar replacement link_limit_var penalty_var penalty_cond bygroup;
  %local i tmp limit_flag bvars2;

  proc sort data=&est_afile. out=est_afile;
    by &aid.;
  run;
  proc sort data=&est_xwalk. out=est_xwalk;
    by &aid. &bid.;
  run;
  data estimation_set1;
    merge est_afile (in=aa) est_xwalk;
    by &aid.;
    if aa;
    %if "&bsortvar."="none" %then %do;
      %let bsortvar=_bsortvar_;
      retain _bsortvar_;
      if first.&aid. then _bsortvar_=0;
      _bsortvar_=_bsortvar_+1;
    %end;
    output;
  run;
  proc sort data=estimation_set1;
    by &bid.;
  run;
  proc sort data=&est_bfile. out=est_bfile;
    by &bid.;
  run;
  data estimation_set1;
    merge est_bfile (in=bb) estimation_set1;
    by &bid.;
    if bb;
  run;
  proc sort data=estimation_set1;
    by &aid. &bsortvar.;
  run;
  data estset;
    set estimation_set1;
    by &aid. &bsortvar.;
    if first.&aid. then output;
  run;
  %fastbb(estset,bb_estimation_set1,&avars. &bvars.,seed=&seed.);
  proc corr data=bb_estimation_set1 outp=ab_covmat cov noprint;
    var &avars. &bvars.;
  run;
  proc sort data=&imp_afile. out=imp_afile;
    by &aid.;
  run;


/***********************
Use the above to predict an average B for each A in both imputation and estimation set
***********************/

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
    sigma11_inv=inv(sigma11);

    use imp_afile;
    read all var{&avars.} into ax_imp;
    read all var{&aid.} into aid_imp;
    read all var{&numlinks_var.} into anum;
    %if "&bygroup." ~= "" %then %do;
      read all var{&bygroup.} into bygroup_imp;
    %end;
    %else %do;
      bygroup_imp=j(nrow(ax_imp),1,1);
    %end;
    %if "&penalty_var." ~= "" %then %do;
      read all var{&penalty_var.} into penalty_var_a;
    %end;
    anobs_imp=nrow(ax_imp);

    bmu_given_ax_imp = t(t(shape(mu2,anobs_imp,nb)) + sigma21*(sigma11_inv)*(t(ax_imp)-t(shape(mu1,anobs_imp,na))));
    bsigma_given_ax_imp = sigma22 - (sigma21*(sigma11_inv)*sigma12);
    call randseed(&seed.);
    noise=randnormal(anobs_imp,j(1,nb,0),bsigma_given_ax_imp);
    tmp_bx=j(anobs_imp,nb,.);
    do i=1 to anobs_imp; 
      tmp_bx[i,]=bmu_given_ax_imp[i,]+noise[i,];
    end;
    full_imp_output=aid_imp || anum || tmp_bx || bygroup_imp %if "&penalty_var." ~= "" %then %do; || penalty_var_a %end;;

    varnames={&aid. &numlinks_var. &bvars. bygroup_imp %if "&penalty_var." ~= "" %then %do; &penalty_var. %end;};
    create impset from full_imp_output[colname=varnames];
    append from full_imp_output;
  quit;

/***********************
Then find covariance of B from this average B on estimation set
***********************/

  data estimation_set1 estimation_set2;
    set estimation_set1;
    by &aid. &bsortvar.;
    if ~last.&aid. then output estimation_set1;
    if ~first.&aid. then output estimation_set2;
  run;
  data estimation_set2;
    set estimation_set1 (drop=&avars. rename=(&aid.=aid1 &bid.=bid1
      %let i=1; %let bvars2=;
      %do %until("%scan(&bvars.,&i.)"="");
        %let tmp=%scan(&bvars.,&i.);
        &tmp.=bhat_&i.
        %let bvars2=&bvars2. bhat_&i.;
        %let i=%eval(&i.+1);
      %end;
      ));
    set estimation_set2 (drop=&avars. rename=(&aid.=aid2 &bid.=bid2));
    if aid1=aid2 and bid1 ne bid2 then output;
  run;
  %fastbb(estimation_set2,bb_estimation_set2,&bvars2. &bvars.,seed=&seed.);
  proc corr data=bb_estimation_set2 outp=bhatb_covmat cov noprint;
    var &bvars2. &bvars.;
  run;
  
/***********************
Use that to draw candidate B's for each A in imputation set
Find nearest neighbors from B's in imputation set to the candidate B's
***********************/

  data impset;
    set impset (rename=(
      %let i=1; %let bvars2=;
      %do %until("%scan(&bvars.,&i.)"="");
        %let tmp=%scan(&bvars.,&i.);
        &tmp.=bhat_&i.
        %let bvars2=&bvars2. bhat_&i.;
        %let i=%eval(&i.+1);
      %end;)) end=lastobs;
    by &aid.;
    retain seed &seed.;
    retain _tmpuni_;
    if first.&aid. then call ranuni(seed,_tmpuni_);
    do _i_=1 to &numlinks_var.;
      if _i_=1 then _firstflag_=1;
      else _firstflag_=0;
      output;
    end;
    if lastobs then call symput("seed",compress(put(seed,12.)));
  run;
  proc sort data=impset;
    by _tmpuni_ _i_;
  run;
  proc iml;
    use bhatb_covmat;
    read all var{&bvars2.} where(_type_="COV") into sigma_left;
    read all var{&bvars.} where(_type_="COV") into sigma_right;
    read all var{&bvars2.} where(_type_="CORR") into rho_left;
    read all var{&bvars.} where(_type_="CORR") into rho_right;
    read all var{&bvars2.} where(_type_="MEAN") into mu1;
    read all var{&bvars.} where(_type_="MEAN") into mu2;
    nbhat=ncol(sigma_left);
    nb=ncol(sigma_right);
    sigma11=sigma_left[1:nbhat,];
    sigma21=sigma_left[nbhat+1:nbhat+nb,];
    sigma22=sigma_right[nbhat+1:nbhat+nb,];
    sigma12=sigma_right[1:nbhat,];
    sigma=sigma_left || sigma_right;
    sigma_inv=inv(sigma);
    sigma11_inv=inv(sigma11);
    * Use standardized Euclidean distance for nearest neighbor match;
    *dist_sigma_inv=inv(diag(sigma));
    * Use Mahalanobis distance for nearest neighbor match;
    dist_sigma_inv=sigma_inv;

    use impset;
    read all var{&bvars2.} into full_bhatx;
    read all var{&aid.} into full_aid;
    read all var{&numlinks_var.} into full_numlinks_a;
    read all var{bygroup_imp} into bygroup_a;
    read all var{_firstflag_} into a_firstflag;
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
      bhatx=full_bhatx[tmp_bygroup_a,];
      numlinks_a=full_numlinks_a[tmp_bygroup_a,];
      anobs=nrow(bhatx);
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

        bsigma_given_bhatx = sigma22 - (sigma21*(sigma11_inv)*sigma12);

        imputed_link=aid || j(anobs,2+ncol(bid),.);
        call randseed(&seed.);
        %if &replacement.=1 %then %do;
          %if &limit_flag.=1 %then %do;
            *** sample with replacement until we reach limit;
            assigned=j(bnobs,1,0);
            link_count=j(bnobs,1,0);
            do i=1 to anobs;
              if min(assigned)=0 then do;
                distances=j(bnobs-sum(assigned),1,.);
tmp_firstflag=a_firstflag[i,]=1;
*print i tmp_firstflag;
                if a_firstflag[i,]=1 then tmp_bx=bhatx[i,];
                else do;
                  noise=randnormal(1,j(1,nb,0),(bnobs/bnobs)*bsigma_given_bhatx);
                  bmu_given_bhatx = t(t(mu2) + sigma21*(sigma11_inv)*(t(tmp_bx-mu1)));
                  tmp_bx=bmu_given_bhatx+noise;
                end;
                tmp_assigned=loc(assigned=0);
                do tmpj=1 to bnobs-sum(assigned);
                  j=tmp_assigned[tmpj];
                  distances[tmpj]=((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]))*dist_sigma_inv*t((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]));
                  %if "&penalty_var." ~= "" %then %do;
                    if abs(pva[i]-pvb[j])>&penalty_cond.
                    then distances[tmpj]=distances[tmpj]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                  %end;
                end;
                tmp_mins=loc(distances=min(distances));
                call randgen(tmp_uni,'UNIFORM');
                tmp_j=tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
                imputed_link[i,1+ncol(aid):ncol(bid)+ncol(aid)] = bid[tmp_j,];
                imputed_link[i,1+ncol(bid)+ncol(aid)] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
                link_count[tmp_j] = link_count[tmp_j] + 1;
                if link_count[tmp_j] >= link_limit[tmp_j] then assigned[tmp_j] = 1;
              end;
              imputed_link[i,2+ncol(bid)+ncol(aid)]=i;
            end;
          %end;
          %else %do;
            *** sample with replacement;
            do i=1 to anobs;
              distances=j(bnobs,1,.);
tmp_firstflag=a_firstflag[i,]=1;
*print i tmp_firstflag;
              if a_firstflag[i,]=1 then tmp_bx=bhatx[i,];
              else do;
                noise=randnormal(1,j(1,nb,0),(bnobs/bnobs)*bsigma_given_bhatx);
                bmu_given_bhatx = t(t(mu2) + sigma21*(sigma11_inv)*(t(tmp_bx-mu1)));
                tmp_bx=bmu_given_bhatx+noise;
              end;
              do j=1 to bnobs;
                distances[j]=((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]))*dist_sigma_inv*t((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]));
                %if "&penalty_var." ~= "" %then %do;
                  if abs(pva[i]-pvb[j])>&penalty_cond.
                  then distances[j]=distances[j]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                %end;
              end;
              tmp_mins=loc(distances=min(distances));
              call randgen(tmp_uni,'UNIFORM');
              imputed_link[i,1+ncol(aid):ncol(bid)+ncol(aid)]=bid[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ,];
              imputed_link[i,1+ncol(bid)+ncol(aid)] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              imputed_link[i,2+ncol(bid)+ncol(aid)]=i;
            end;
          %end;
        %end;
        %else %do;
          *** sample without replacement;
          assigned=j(bnobs,1,0);
          do i=1 to anobs;
            if min(assigned)=0 then do;
              distances=j(bnobs-sum(assigned),1,.);
tmp_firstflag=a_firstflag[i,]=1;
*print i tmp_firstflag;
              if a_firstflag[i,]=1 then tmp_bx=bhatx[i,];
              else do;
                noise=randnormal(1,j(1,nb,0),(bnobs/bnobs)*bsigma_given_bhatx);
                bmu_given_bhatx = t(t(mu2) + sigma21*(sigma11_inv)*(t(tmp_bx-mu1)));
                tmp_bx=bmu_given_bhatx+noise;
              end;
              tmp_assigned=loc(assigned=0);
              do tmpj=1 to bnobs-sum(assigned);
                j=tmp_assigned[tmpj];
                distances[tmpj]=((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]))*dist_sigma_inv*t((bhatx[i,] || tmp_bx)-(bhatx[i,] || bx[j,]));
                %if "&penalty_var." ~= "" %then %do;
                  if abs(pva[i]-pvb[j])>&penalty_cond.
                  then distances[tmpj]=distances[tmpj]+(1000*(abs(pva[i]-pvb[j])-&penalty_cond.));
                %end;
              end;
              tmp_mins=loc(distances=min(distances));
              call randgen(tmp_uni,'UNIFORM');
              imputed_link[i,1+ncol(aid):ncol(bid)+ncol(aid)]=bid[ tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ] ,];
              imputed_link[i,1+ncol(bid)+ncol(aid)] = distances[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ];
              assigned[ tmp_assigned[ tmp_mins[ ceil(tmp_uni*ncol(tmp_mins)) ] ] ] = 1;
            end;
            imputed_link[i,2+ncol(bid)+ncol(aid)]=i;
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

    varnames={&aid. &bid. distance order &bygroup.};
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





