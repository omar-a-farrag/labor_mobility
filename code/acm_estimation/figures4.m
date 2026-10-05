%%% FIGURES %%%

clear

load simula_tradable_b097/result2
typ=1;
Lx(:,:,typ)=L(:,:);
wgx(:,:,typ)=wg(:,:);
vx(:,:,typ)=v(:,:);
tradex(:,typ)=trade(:);
pricex(:,:,typ)=price(:,:);
outtx(:,:,typ)=outt(:,:);
contx(:,:,typ)=cont(:,:);

load simula_nontra_b097/result2
typ=2;
Lx(:,:,typ)=L(:,:);
wgx(:,:,typ)=wg(:,:);
vx(:,:,typ)=v(:,:);
tradex(:,typ)=trade(:);
pricex(:,:,typ)=price(:,:);
outtx(:,:,typ)=outt(:,:);
contx(:,:,typ)=cont(:,:);

load simula_tradable_b090/result2
typ=3;
Lx(:,:,typ)=L(:,:);
wgx(:,:,typ)=wg(:,:);
vx(:,:,typ)=v(:,:);
tradex(:,typ)=trade(:);
pricex(:,:,typ)=price(:,:);
outtx(:,:,typ)=outt(:,:);
contx(:,:,typ)=cont(:,:);

load simula_nontra_b090/result2
typ=4;
Lx(:,:,typ)=L(:,:);
wgx(:,:,typ)=wg(:,:);
vx(:,:,typ)=v(:,:);
tradex(:,typ)=trade(:);
pricex(:,:,typ)=price(:,:);
outtx(:,:,typ)=outt(:,:);
contx(:,:,typ)=cont(:,:);


lw=1;
TS=4;

fig_title='Basic_All_';

Tbar=p.trans_l;

s(1).typtitle=' (tradable, \beta=0.97).';
s(2).typtitle=' (nontradable, \beta=0.97).';
s(3).typtitle=' (tradable, \beta=0.90).';
s(4).typtitle=' (nontradable, \beta=0.90).';

T=-4:Tbar-1-11;
TT=1+1:Tbar+5-11;


figure(1);
set(1,'Color','w')
set(1,'Position',[1   100   720   600])

for typ=1:TS
subplot(2,2,typ)

plot(T,Lx(TT,1, typ),'b-',T,Lx(TT,2, typ),'b-.',T,Lx(TT,3, typ),'b--',T,Lx(TT,4, typ),'r-',T,Lx(TT,5, typ),'r-.',T,Lx(TT,6, typ),'r--','LineWidth',lw)

%title(strcat('Labor shares',' - type ', int2str(typ) ) );
title(strcat('Labor Allocation', s(typ).typtitle ) );
%legend('Agriculture','Construction','Manufacturing','Transp./Util.','Trade','Service');
legend('A','C','M','U','T','S')
%','Service');
xlabel('time')
ylabel('Fraction of Labor Force')


end;
filename=strcat(fig_title,'_1' ) 
print(1,'-dtiff',filename)

figure(2);
set(2,'Color','w')
set(2,'Position',[1   100   720   600])

for typ=1:TS
subplot(2,2,typ)

plot(T,wgx(TT,1, typ),'b-',T,wgx(TT,2, typ),'b-.',T,wgx(TT,3, typ),'b--',T,wgx(TT,4, typ),'r-',T,wgx(TT,5, typ),'r-.',T,wgx(TT,6, typ),'r--','LineWidth',lw)

title(strcat('Wages', s(typ).typtitle ) );
%legend('Agriculture','Construction','Manufacturing','Transp./Util.','Trade','Service');
legend('A','C','M','U','T','S')
xlabel('time')
ylabel('Wages (Normalized)')
end;
filename=strcat(fig_title,'_2' ) 
print(2,'-dtiff',filename)

figure(3);
set(3,'Color','w')
set(3,'Position',[1   100   720   600])

for typ=1:TS
subplot(2,2,typ)

plot(T,vx(TT,1, typ),'b-',T,vx(TT,2, typ),'b-.',T,vx(TT,3, typ),'b--',T,vx(TT,4, typ),'r-',T,vx(TT,5, typ),'r-.',T,vx(TT,6, typ),'r--','LineWidth',lw)

title(strcat('Values', s(typ).typtitle ) );
%legend('Agriculture','Construction','Manufacturing','Transp./Util.','Trade','Service');
legend('A','C','M','U','T','S')
xlabel('time')
ylabel('Present Discounted Values')
end;
filename=strcat(fig_title,'_3' ) 
print(3,'-dtiff',filename)



figure(4);
set(4,'Color','w')
set(4,'Position',[1   100   720   600])

for typ=1:TS
subplot(2,2,typ)


subplot(2,2,typ)
plot(T,tradex(TT,typ),'b-',T,contx(TT,3,typ),'b-.',T,outtx(TT,3,typ),'b--','LineWidth',lw)

title(strcat('Manufacturing Trade', s(typ).typtitle ));
legend('Imp.','Cons.','Prod.');

xlabel('time')
ylabel('Real Output')

end;

filename=strcat(fig_title,'_4' ) 
print(4,'-dtiff',filename)


figure(5);
set(5,'Color','w')
set(5,'Position',[1   100   720   600])

for typ=1:TS
subplot(2,2,typ)

subplot(2,2,typ)
plot(T,pricex(TT,1,typ),'b-',T,pricex(TT,2,typ),'b-.',T,pricex(TT,3,typ),'b--',T,pricex(TT,4,typ),'r-',T,pricex(TT,5,typ),'r-.',T,pricex(TT,6,typ),'r--','LineWidth',lw)
axis([-5 Tbar-1-11 0.6 1.2])

title(strcat('Prices', s(typ).typtitle ));
%legend('Agriculture','Construction','Manufacturing','Transp./Util.','Trade','Service');
legend('A','C','M','U','T','S')
xlabel('time')
ylabel('Price')

end;

filename=strcat(fig_title,'_5' ) 
print(5,'-dtiff',filename)