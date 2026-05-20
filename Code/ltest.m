% Linearity test against a Logistic STAR specification.
% The test is based on the third-order Taylor series expansion of the
% logistic function arounf the null hypothesis.
% Last update: February 5, 2010.

function [isLinear,pvalue]=ltest(y,X,W,q,flag,sig,N)

% inputs:
% ------
% y: dependent variable.
% X: regressors, including a constant.
% W: regressors with fixed coefficients.
% q: transition variable.
% flag: dummy variable indicating if q belongs to X (flag = 1) or not (flag = 0).
% sig: significance level(s).
% N: dimension of sig.

% outputs:
% -------
% isLinear: dummy variable indicating if linearity is rejected or not.
% pvalue: p-value of the linearity test. 

XX = [X W];
[T,nX] = size(X);

% Linear Model (Null hypothesis)
% -----------------------------
b    = inv(XX'*XX)*XX'*y;
u    = y - XX*b;
SSE0 = sumsqr(u);

XH0  = XX;

% Regressors under the alternative
% --------------------------------
if flag == 1
    q   = repmat(q,1,nX-1);
    XH1 = [X(:,2:nX).*q X(:,2:nX).*(q.^2) X(:,2:nX).*(q.^3)];
else
    q   = repmat(q,1,nX);
    XH1 = [X.*q X.*(q.^2) X.*(q.^3)];
end

Z   = [XH0 XH1];

% Standardize the regressors
% --------------------------
nZ        = size(Z,2);
stdZ      = std(Z);
stdZ      = repmat(stdZ,T,1);
Z(:,2:nZ) = Z(:,2:nZ)./stdZ(:,2:nZ);


% Nonlinear Model (Alternative hypothesis)
% ----------------------------------------
c   = pinv(Z'*Z)*Z'*u;
e   = u - Z*c;
SSE = sumsqr(e);

% Compute the test statistic
% --------------------------
nXH0 = size(XH0,2);
nXH1 = size(XH1,2);

F = ((SSE0-SSE)/nXH1)/(SSE/(T-nXH0-nXH1));
F = ones(N,1)*F;
f = finv(sig,nXH1,T-nXH0-nXH1);
f = f';
isLinear = F <= f;
pvalue = 1-fcdf(F,nXH1,T-nXH0-nXH1);