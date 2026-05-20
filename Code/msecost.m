function [f,J]=msecost(PSI,y,X,W,q,m)

[T,nX] = size(X);
nW     = size(W,2);

[gamma,c] = getpar(PSI);

Z = [X W];
fX = zeros(T,m);
dfX = zeros(T,m);
for i=1:m
    fX(:,i)  = siglog(gamma(i)*(q-c(i)));
    dfX(:,i) = dsiglog(fX(:,i));
    Z        = [Z repmat(fX(:,i),1,nX).*X];
end
theta  = pinv(Z'*Z)*Z'*y;
alpha  = theta(1:nX);
if isempty(W)==1
    beta=[];
else
    beta   = theta(nX+1:nX+nW);
end
lambda = reshape(theta(nX+nW+1:end),nX,m);
if isempty(W)==1
    yhat   = X*alpha + sum((fX*lambda').*X,2);
else
    yhat   = X*alpha + W*beta + sum((fX*lambda').*X,2);
end; 
ehat   = y - yhat;
f      =  sum(ehat.^2)/T;

[ggamma,gc] = gradG(PSI,X,q,lambda,dfX,m);

J = sum(-2*(repmat(ehat,1,2*m).*[ggamma,gc])/T);