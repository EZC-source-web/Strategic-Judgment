function [ggamma,gc]=gradG(PSI,X,q,lambda,dfX,m)

[gamma,c] = getpar(PSI);

for i=1:m
    ggamma(:,i) = (X*lambda(:,i)).*(dfX(:,i).*(q-c(i)));
    gc(:,i)     = -(X*lambda(:,i)).*(gamma(i)*dfX(:,i));
end