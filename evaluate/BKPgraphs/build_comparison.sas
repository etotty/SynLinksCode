
libname v6 "REDACTED SSB V6.0 PATH";
%let syn_v6=ssb_v6_0_2_synthetic1_1;
libname v7 "REDACTED SSB V7.0 PATH";
%let syn_v7=ssb_v7_0_synthetic1;
libname outlib "./";

data outlib.comparison_v6;
  set v6.&syn_v6.
    (keep=panel personid spouse_personid flag_valid_ssn
       male race hispanic foreign_born time_arrive_usa educ_5cat 
       own_home homeequity nonhouswealth total_der_fica_2009
     where=(panel=2008 and (race=1 or race=2) and hispanic ge 0
       and (foreign_born=0 or time_arrive_usa>0) and educ_5cat>0
       and (own_home=0 or homeequity>-100000000) and nonhouswealth>-100000000 and flag_valid_ssn=1));
  if spouse_personid>0 then linked_couple=1;
  if own_home<0 then own_home=0;
  if total_der_fica_2009<0 then total_der_fica_2009=0;
run;
data outlib.comparison_v7;
  set v7.&syn_v7.
    (keep=panel personid spouse_personid flag_valid_ssn
       male race hispanic foreign_born time_arrive_usa educ_5cat 
       own_home homeequity nonhouswealth total_der_fica_2009
     where=(panel=2008 and (race=1 or race=2) and hispanic ge 0
       and (foreign_born=0 or time_arrive_usa>0) and educ_5cat>0
       and (own_home=0 or homeequity>-100000000) and nonhouswealth>-100000000 and flag_valid_ssn=1));
  if spouse_personid>0 then linked_couple=1;
  if own_home<0 then own_home=0;
  if total_der_fica_2009<0 then total_der_fica_2009=0;
run;






