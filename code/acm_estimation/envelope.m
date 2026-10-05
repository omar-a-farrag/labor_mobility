
load result2.mat


for t=1:5
    L(t,1:DN)=L_s(1:DN);
    wg(t,1:DN)=w_s(1:DN);
    v(t,1:DN)=vs(1:DN);
    v_n(t,1:DN)=vs(1:DN);
    price(t,1:DN)=p.price_A;
    outt(t,1:DN)=output;
    cont(t,1:DN)=consumption;
    trade(t,1)=consumption(p.lib_sec)-output(p.lib_sec);
    flt(1:DN,1:DN,t)=fl(1:DN,1:DN);
end;


% FT SS
t=1;
vsf(1,1:DN)=yy_tsf(t,1:DN);
L_inf(1,1:DN)=yy_tsf(t,DN+1:2*DN);
pricef(1,1:DN)=yy_tsf(t,2*DN+1:3*DN);
p.price=pricef;
[w_sf,cpif,epricef,outputf,toutputf,consumptionf] = mProfit(L_inf,p);
tconsumptionf=sum(consumptionf.*pricef);
[L_sf,flf,omegaf]=mij(vsf,p,L_inf);

% TRANS
L_=L_s;

for t=1:p.trans_l,
    tau=min([t+1 p.trans_l]);
    v(t+5,1:DN)=yy_t(t,1:DN);
    v_n(t+5,1:DN)=yy_t(tau,1:DN);
    price(t+5,1:DN)=yy_t(tau,DN+1:2*DN);
    p.price=price(t+5,1:DN);
    [w_,cpi_,eprice_,output_,toutput_,consumption_] = mProfit(L_,p);
    wg(t+5,1:DN) = w_(1,1:DN);
    outt(t+5,1:DN)=output_(1,1:DN);
    cont(t+5,1:DN)=consumption_(1,1:DN);
    trade(t+5,1)=consumption_(3)-output_(3);
    [L_,fl,omega]=mij(v_n(t+5,1:DN),p,L_);
    L(t+5,1:DN)=L_(1,1:DN);
    flt(1:DN,1:DN,t+5)=fl(1:DN,1:DN);
end;
v1=vs(1,1:DN);

[L_,fl,omega]=mij(v(2,1:DN),p,L_s);
v2=w_s+p.Bta*v(1,1:DN)+omega;


% TRUE ENVELOPE

fl_a(1:DN,1:DN)=flt(1:DN,1:DN,1);

v_env_=zeros(DN,1);

for tt=1:5000
    
    v_env_= w_sf' + p.Bta*flf*(v_env_);
     
    
end;

t=35;
v_env1(t,:)=v_env_;
w_=zeros(1,6);

for t=34:-1:6
    
    fl_(1:DN,1:DN)=flt(1:DN,1:DN,t);
    w_=wg(t,1:DN);
    v_env_= w_' + p.Bta*fl_*(v_env_);
    v_env1(t,:)=v_env_;
    
end;

v_env_a=zeros(DN,1);

for tt=1:5000
    
    
    v_env_a= w_s' + p.Bta*fl_a*(v_env_a);
     
    
end;

for t=1:5
    v_env1(t,:)=v_env_a;
end;

% ENVELOPE WITH TRUE WAGES & BIASED FLOWS


fl_a(1:DN,1:DN)=flt(1:DN,1:DN,1);

v_env_=zeros(DN,1);

for tt=1:5000
    
    v_env_= w_sf' + p.Bta*fl_a*(v_env_);
     
    
end;

t=35;
v_env2(t,:)=v_env_;
w_=zeros(1,6);

for t=34:-1:6
    
    fl_(1:DN,1:DN)=flt(1:DN,1:DN,t);
    w_=wg(t,1:DN);
    v_env_= w_' + p.Bta*fl_a*(v_env_);
    v_env2(t,:)=v_env_;
    
end;

v_env_a=zeros(DN,1);

for tt=1:5000
    
    
    v_env_a= w_s' + p.Bta*fl_a*(v_env_a);
     
    
end;

for t=1:5
    v_env2(t,:)=v_env_a;
end;



% ENVELOPE WITH BIASED WAGES & BIASED FLOWS


fl_a(1:DN,1:DN)=flt(1:DN,1:DN,1);

v_env_=zeros(DN,1);

indx=[1 2 4 5 6];

for tt=1:5000
    w_=w_sf;
    w_(indx)=w_s(indx)/cpif;
    
    v_env_= w_' + p.Bta*fl_a*(v_env_);
     
    
end;

t=35;
v_env3(t,:)=v_env_;
w_=zeros(1,6);

for t=34:-1:6
    
    fl_(1:DN,1:DN)=flt(1:DN,1:DN,t);
    
    w_=wg(t,1:DN);
    w_(indx)=w_s(indx)/cpif;
    
    v_env_= w_' + p.Bta*fl_a*(v_env_);
    v_env3(t,:)=v_env_;
    
end;

v_env_a=zeros(DN,1);

for tt=1:5000
    
    
    v_env_a= w_s' + p.Bta*fl_a*(v_env_a);
     
    
end;

for t=1:5
    v_env3(t,:)=v_env_a;
end;


res3=[...
p.Bta*(v(6,:)-v(5,:));... %./v(5,:)
p.Bta*(v_env1(6,:)-v_env1(5,:));... %./v_env1(5,:)
p.Bta*(v_env2(6,:)-v_env2(5,:));... %./v_env2(5,:)
p.Bta*(v_env3(6,:)-v_env3(5,:)) ]%./v_env3(5,:)

res3_=[...
p.Bta*(v(6,:)-v(5,:))./v(5,:);... 
p.Bta*(v_env1(6,:)-v_env1(5,:))./v_env1(5,:);... 
p.Bta*(v_env2(6,:)-v_env2(5,:))./v_env2(5,:);... 
p.Bta*(v_env3(6,:)-v_env3(5,:))./v_env3(5,:) ] 

save result3.mat;




