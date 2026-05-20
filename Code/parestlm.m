function [alpha,beta,lambda,gamma,c,fX,yhat,ehat,G]=parestlm(y,X,W,q,T,nX,nW,m,gamma,c)

% Compute starting values
% -----------------------
[alpha,beta,lambda,gamma,c] = startval(y,X,W,q,m,gamma,c);
PSI = setpar(gamma,c);

options = optimset('Display','on','Jacobian', 'on', 'MaxFunEvals',1e10,...
        'LargeScale','off','MaxIter',4000,'TolFun',1e-10,...
        'DerivativeCheck','off','LevenbergMarquardt','on',...
        'LineSearchType','cubicpoly','TolX',1e-10,'TolCon',1e-10);
 
PSI = fmincon('msecost',PSI,[],[],[],[],...
             [zeros(m,1);ones(m,1)*prctile(q,10)],...
             [inf(m,1);ones(m,1)*prctile(q,90)],[],options,...
              y,X,W,q,m);

[gamma,c] = getpar(PSI);

aux   = [gamma c];
aux   = sortrows(aux,2);
gamma = aux(:,1);
c     = aux(:,2);

Z = [X W];
fX = zeros(T,m);
dfX = zeros(T,m);
for i=1:m
    fX(:,i)  = siglog(gamma(i)*(q-c(i)));
    dfX(:,i) = dsiglog(fX(:,i));
    Z        = [Z repmat(fX(:,i),1,nX).*X];
end
theta  = inv(Z'*Z)*Z'*y;
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

PSI = setpar(gamma,c);

[ggamma,gc] = gradG(PSI,X,q,lambda,dfX,m);

galpha  = X;
glambda = Z(:,nX+nW+1:end);
gbeta   = W;
G = [galpha,gbeta,glambda,ggamma,gc];
