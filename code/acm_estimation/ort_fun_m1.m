function [m,e,ss]=ort_fun_m1(b,info1, W, y, X, Z)


bta=info1.beta;
%delta=info1.delta;
typ=1;
TS=1;

nu=b(1);
sizec=length(b)-1;
Coef=zeros(3,TS);

Coef(1,typ)=bta;
Coef(2,typ)=bta/nu;
Coef(3:sizec+2,typ)=((1-bta)/nu)*b(2:1+sizec);
    
e=-y+X*Coef(:,typ);
m=Z'*e/length(e);

ss=m'*W*m;
