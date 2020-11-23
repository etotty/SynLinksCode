
libname a "REDACTED PATH TO GOLD STANDARD FILE";
libname b "./";


data testfile (drop=nonwhite black flag_valid_ssn);
  *** gsf_subset is the subset of the GSF used to create the SSB;
  set a.gsf_subset
    (keep=panel rot state personid spouse_personid mom_personid flag_valid_ssn
       sipp_birthdate male nonwhite black hispanic foreign_born time_arrive_usa educ_5cat 
       own_home homeequity nonhouswealth total_der_fica_2009 total_der_fica_2010
     where=(panel=2008 and (nonwhite=0 or black ge 0) and hispanic ge 0
       and (foreign_born=0 or time_arrive_usa>0) and educ_5cat>0
       and (own_home=0 or homeequity>-100000000) and nonhouswealth>-100000000 and flag_valid_ssn=1));
  if nonwhite=0 then race=1;
  else if black=1 then race=2;
  else race=3;
  if own_home<0 then own_home=0;
  if total_der_fica_2009<0 then total_der_fica_2009=0;
  if total_der_fica_2010<0 then total_der_fica_2010=0;
  if panel-year(sipp_birthdate)<18 then do;
    if mom_personid>0 then do;
      spouse_personid=.;
      output;
    end;
  end;
  else do;
    mom_personid=.;
    output;
  end;
run;
proc sort data=testfile;
  by personid;
run;
data just_ids (keep=personid rename=(personid=pid));
  set testfile;
run;

proc sort data=testfile;
  by mom_personid;
run;
data testfile;
  merge testfile (in=aa) just_ids (keep=pid in=bb rename=(pid=mom_personid));
  by mom_personid;
  if aa;
  if ~bb then mom_personid=.;
  if mom_personid>0 then linked_child=1; else linked_child=0;
  if linked_child=1 or panel-year(sipp_birthdate)<18 then do;
    if spouse_personid>0 then spouse_personid=.;
  end;
run;
data just_ids (keep=personid spouse_personid rename=(personid=pid spouse_personid=spid));
  set testfile;
  if spouse_personid>0 then output;
run;
proc sort data=just_ids;
  by spid pid;
run;

proc sort data=testfile;
  by personid spouse_personid;
run;
data testfile;
  merge testfile (in=aa) just_ids (in=bb rename=(pid=spouse_personid spid=personid));
  by personid spouse_personid;
  if aa;
  if ~bb then spouse_personid=.;
  if spouse_personid>0 then linked_couple=1; else do; linked_couple=0; spouse_personid=.; end;
  if linked_couple=1 or linked_child=1 or panel-year(sipp_birthdate) ge 18 then output;
run;

data
  males (keep=m_personid f_personid m_own_home m_homeequity m_nonhouswealth m_state)
  females (keep=m_personid f_personid f_own_home f_homeequity f_nonhouswealth f_state)
  kids (keep=k_personid f_personid);
  set testfile;
  if linked_child=0 then do;
    if male=0 then do;
      m_personid=spouse_personid;
      f_personid=personid;
      f_own_home=own_home;
      f_homeequity=homeequity;
      f_nonhouswealth=nonhouswealth;
      f_state=state;
      output females;
    end;
    else if male=1 then do;
      f_personid=spouse_personid;
      m_personid=personid;
      m_own_home=own_home;
      m_homeequity=homeequity;
      m_nonhouswealth=nonhouswealth;
      m_state=state;
      output males;
    end;
  end;
  else do;
    k_personid=personid;
    f_personid=mom_personid;
    output kids;
  end;
run;
proc sort data=males;
  by f_personid m_personid;
run;
proc sort data=females;
  by f_personid m_personid;
run;
proc sort data=kids;
  by f_personid k_personid;
run;
data test_hh;
  merge males (in=aa) females (in=bb);
  by f_personid m_personid;
  if aa or bb;
  num_adults=0;
  if aa then num_adults=num_adults+1;
  if bb then num_adults=num_adults+1;
run;  
data test_hh;
  merge test_hh (in=aa) kids (in=bb);
  by f_personid;
  if aa;
run;
proc sort data=test_hh;
  by m_personid f_personid k_personid;
run;
data b.hh_file (keep=hhid state own_home nonzero_he homeequity nonzero_nhw nonhouswealth num_adults num_kids)
  test_people (keep=hhid hhh_flag personid);
  set test_hh;
  by m_personid f_personid;
  retain num_kids hhid seed 0;
  retain own_home homeequity nonhouswealth state;
  if first.f_personid then do;
    num_kids=0;
    hhid=sum(hhid,1);
    own_home=max(m_own_home,f_own_home);
    homeequity=max(m_homeequity,f_homeequity);
    nonhouswealth=max(m_nonhouswealth,f_nonhouswealth);
    call ranuni(seed,x);
    if m_personid>0 and f_personid>0 then do;
      if x>0.5 then do;
        state=m_state;
        hhh_flag=1; personid=m_personid; output test_people;
        hhh_flag=0; personid=f_personid; output test_people;
      end;
      else do;
        state=f_state;
        hhh_flag=0; personid=m_personid; output test_people;
        hhh_flag=1; personid=f_personid; output test_people;
      end;
    end;
    else if m_personid>0 then do;
      state=m_state;
      hhh_flag=1; personid=m_personid; output test_people;
    end;
    else if f_personid>0 then do;
      state=f_state;
      hhh_flag=1; personid=f_personid; output test_people;
    end;
  end;
  if k_personid>0 then do;
    num_kids=num_kids+1;
    personid=k_personid;
    hhh_flag=0;
    output test_people;
  end;
  if last.f_personid then do;
    if nonhouswealth=0 then do;
      nonzero_nhw=0;
      nonhouswealth=.;
    end;
    else nonzero_nhw=1;
    if own_home=1 then do;
      if homeequity=0 then do;
        nonzero_he=0;
        homeequity=.;
      end;
      else nonzero_he=1;
    end;
    else nonzero_he=.;
    output b.hh_file;
  end;
run;

proc sort data=test_people;
  by personid;
run;
proc sort data=testfile;
  by personid;
run;
data person_file (drop=own_home homeequity nonhouswealth);
  merge testfile (in=aa) test_people (in=bb);
  by personid;
  if aa;
  if total_der_fica_2009 le 0 then do;
    pos_der_fica_2009=0;
    total_der_fica_2009=.;
  end;
  else pos_der_fica_2009=1;
  if total_der_fica_2010 le 0 then do;
    pos_der_fica_2010=0;
    total_der_fica_2010=.;
  end;
  else pos_der_fica_2010=1;
run;

data moms (keep=personid);
  set person_file (keep=mom_personid where=(mom_personid>.));
  personid=mom_personid;
run;
proc sort data=moms;
  by personid;
run;
data moms;
  set moms;
  by personid;
  retain num_kids 0;
  if first.personid then num_kids=0;
  num_kids=num_kids+1;
  if last.personid then output;
run;
data b.person_file;
  merge person_file (in=aa) moms (in=bb);
  by personid;
  if aa;
  if bb then linked_mom=1; else linked_mom=0;
run;

proc means data=b.hh_file;
proc means data=b.person_file;
proc freq data=b.person_file;
  tables male*linked_couple;
run;




















