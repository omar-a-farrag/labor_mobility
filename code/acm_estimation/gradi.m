function [G,GP,GM,fx,e, g, gm] = gradi(f,x,varargin)

eps = 1e-8;

n = length(x);
fx = feval(f,x,varargin{:});
m=length(fx(:,1)); 

h = eps.^(1/3)*max(abs(x),1e-8);
xh = x+h;
h = xh-x;   
e = sparse(1:n,1:n,h,n,n);
 

g = zeros(m,n);
gm = zeros(m,n);
for i=1:n
    %'STEP'
    %i
    g(:,i) = feval(f,x+e(:,i),varargin{:});
    gm(:,i) = feval(f,x-e(:,i),varargin{:});
  
    G(:,i) = (g(:,i)-gm(:,i))/(2*h(i));
    GP(:,i)= (g(:,i)-fx(:,1))/h(i);
    GM(:,i)= (fx(:,1)-gm(:,i))/h(i);
end
