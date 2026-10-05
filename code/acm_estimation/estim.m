% wages are 

clear;

load mij_data_lin1

load cpi6701.txt
%load sonuc4.mat

T=26;

step_=1;
k=1; %years
lag=2;
TI=5; %months

xin_=[2; 10];

alpha=0;

%CON=[1 1 2 3 3 4 4 4 5 5 6 6 6 6 6 6];
CON=[1 1 2 3 3 4 4 4 5 5 6 6 6 6 6 6];
%CON=[1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16];
%CON=1:16;
isize=max(CON);

AA1=Xbig.*bt;
%AA2=sum(AA1(:,1:18),2);
for t=1:26
    for i=1:6
        
        %waget(i,t)=exp( bt(t,i)*sum(Xbig(t,1:6)) + bt(t,i+6)*sum(Xbig(t,7:12)) + bt(t,i+12)*sum(Xbig(t,13:18)) + sum(AA1(t,19:24)));
        %waget(i,t)=exp(bt(t,i)+sum(AA1(t,7:14)));    
    end;
end;

%waget=41483*26*6*waget/sum(sum(waget));


%save mij_data

% clear wage wage_ obs_ind i j ii t 
% 
% 
% mwage=sum(sum(waget))/(26*6);
% save data_matrices_.mat 

for tau=1:floor(26/k),
   for i=1:isize,
   for j=1:isize,
      
      tmp_=0;
      coefsum_=0;
      for ii=1:k,
          coef=sum( mij_n(i,:,k*(tau-1)+ii ),2);  
          coefsum_=coefsum_+coef;
          tmp_=tmp_ + coef*mij(i,j,k*(tau-1)+ii);                
      end;
      mij_tmp(i,j)=tmp_/coefsum_;
        
   end;    
   end;
   
   for i=1:isize,
        waget_(i,tau)= ( sum( waget(i,k*(tau-1)+1:k*(tau-1)+k ) )/41483 );
   end;
   
   A(1:isize,1:isize)=mij_tmp(1:isize,1:isize);
   %%%% DIKKAT
   B=A^(k*12/TI);
   mij_(1:isize,1:isize,tau)=real( B(1:isize,1:isize) );
end;

cnt=1;
for t=1+lag:floor(26/k)-1,
    for i=1:isize,
        for j=1:isize,

            data_tmp(1)=-( log(mij_(i,j,t)/mij_(i,i,t)) );
            data_tmp(2)=log(mij_(i,j,t+1)/mij_(j,j,t+1));
            data_tmp(3)=( (waget_(j,t+1)) - (waget_(i,t+1)) );
            data_tmp(4)=-1;
            
            data_tmp2(1)=-( log(mij_(i,j,t-lag)/mij_(i,i,t-lag)) );
            data_tmp2(2)=log(mij_(i,j,t+1-lag)/mij_(j,j,t+1-lag));
            data_tmp2(3)=( (waget_(j,t+1-lag)) - (waget_(i,t+1-lag)) );
            data_tmp2(4)=-1;
            
            if i~=j && mij_(i,j,t) > 0 && mij_(i,j,t+1)>0 && mij_(i,j,t-lag) > 0 && mij_(i,j,t+1-lag)>0,                                
                data(cnt,1:4)=data_tmp(1:4);
                data2(cnt,1:4)=data_tmp2(1:4);
                cnt=cnt+1;
            end; 
            
        end;
    end;
end;


% ESTIMATE

y=-data(:,1);
n=length(y(:,1));

X=data(:,2:4); 
Z=data2(:,2:4) ;

% %-------------------------------------
opt=optimset('MaxFunEvals',100000000,'MaxIter',1000000);

W=eye(3);
load W.txt
W_=zeros(3,3);

p.beta=0.97^k;

while sum(sum((W-W_).^2))>0.00001;
    
    xin=fminsearch(@ort_fun_1,xin_,opt,p,W,y,X,Z)
    [m,e]=ort_fun_m1(xin,p,W,y,X,Z);
    
    SS = (n/(n-length(xin)))*kron(e'*e/n,Z'*Z/n);
    
    W_=W;
    W=inv(SS);
    
end;

G=gradi(@ort_fun_m1,xin,p,W,y,X,Z);

V=inv(G'*W*G)/(n);
se3=sqrt(diag(V));

[xin se3 xin./se3]

sonuc(1,1)=xin(1);
sonuc(1,2)=xin(1)/se3(1);
sonuc(1,3)=xin(2);
sonuc(1,4)=xin(2)/se3(2);
%---------------------------------

opt=optimset('MaxFunEvals',100000000,'MaxIter',1000000);


W=eye(3);
load W.txt
W_=zeros(3,3);

p.beta=0.90^k;

xin=fminsearch(@ort_fun_1,xin_,opt,p,W,y,X,Z)
[m,VO,ss]=ort_fun_m1(xin,p,W,y,X,Z);

while sum(sum((W-W_).^2))>0.00001;
    
    xin=fminsearch(@ort_fun_1,xin_,opt,p,W,y,X,Z)
    [m,e]=ort_fun_m1(xin,p,W,y,X,Z);
    
    SS = (n/(n-length(xin)))*kron(e'*e/n,Z'*Z/n);
    
    W_=W;
    W=inv(SS);

end;

G=gradi(@ort_fun_m1,xin,p,W,y,X,Z);

V=inv(G'*W*G)/n;
se3=sqrt(diag(V))*(n/(n-length(xin)));


[xin se3 xin./se3]

sonuc(1,5)=xin(1);
sonuc(1,6)=xin(1)/se3(1);
sonuc(1,7)=xin(2);
sonuc(1,8)=xin(2)/se3(2);

%------------------------------

sonuc


%save W.txt
