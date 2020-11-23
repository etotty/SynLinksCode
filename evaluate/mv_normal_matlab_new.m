%Performs Royston (1982) test for multivariate normality.

%The test is a function file named 'roystest' downloaded 
%	from mathworks.

%The data comes from couples.csv, which is a dataset 
%	of 10 transformed factors for males and 10 for 
%	females. 

alpha=.05;
X = csvread('couples_new.csv',1,0);
[N,~]=size(X);

Xsample=datasample(X,2000,1,'Replace',false);

Xboth=zeros(2000,20);
Xboth(:,1:10)=Xsample(:,2:11);
Xboth(:,11:20)=Xsample(:,13:22);9.76
0.88


Xfemales=Xsample(:,2:11);
Xmales=Xsample(:,13:22);


% Royston test for multivariate normality
[test_both,Zw_both]=roystest(Xboth,alpha);
[test_females,Zw_females]=roystest(Xfemales,alpha);
[test_males,Zw_males]=roystest(Xmales,alpha);

% Shapiro Wilk test for univariate normality
pValue=zeros(20,1);
for p=1:20
    [H, pValue(p,1), W] = swtest(Xboth(:,p), alpha)
end

save('./mv_normal_matlab_results_new.mat')

