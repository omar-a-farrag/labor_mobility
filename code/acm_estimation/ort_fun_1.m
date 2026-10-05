function ss=ort_fun_1(b,info1, W, y, X, Z)

bta=info1.beta;
%delta=info1.delta;
typ=1;
TS=1;

nu=b(1);
sizec=length(b)-1;
Coef=zeros(3,TS);

Coef(1,typ)=bta;
Coef(2,typ)=bta/nu;
Coef(3:sizec+2,typ)=((1-bta)/nu)*b(2:sizec+1);
    
e=-y+X*Coef(:,typ);
m=Z'*e/length(e);
   
ss=m'*W*m;

% --- THE PENALTY FIX FOR RESTRICTED ESTIMATION ---
% Forces the optimizer to hold nu at the target without breaking standard errors
global apply_penalty target_nu_A target_nu_B;
if ~isempty(apply_penalty) && apply_penalty == 1
    % Using a small tolerance for floating-point safety
    if abs(bta - 0.97) < 0.01
        ss = ss + 1e10 * (nu - target_nu_A)^2;
    elseif abs(bta - 0.90) < 0.01
        ss = ss + 1e10 * (nu - target_nu_B)^2;
    end
end

% function ss=ort_fun_1(b,info1, W, y, X, Z)
% 
% bta=info1.beta;
% %delta=info1.delta;
% typ=1;
% TS=1;
% 
% nu=b(1);
% sizec=length(b)-1;
% Coef=zeros(3,TS);
% 
% Coef(1,typ)=bta;
% Coef(2,typ)=bta/nu;
% Coef(3:sizec+2,typ)=((1-bta)/nu)*b(2:sizec+1);
% 
% e=-y+X*Coef(:,typ);
% m=Z'*e/length(e);
% 
% ss=m'*W*m;