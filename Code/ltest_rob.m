% Robust version of the linearity test against a Logistic STAR specification.
% The test is based on the third-order Taylor series expansion of the
% logistic function arounf the null hypothesis.
% Last update: February, 2010.

function [isLinear,pvalue]=ltest_rob(y,X,W,q,flag,sig,N)

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

% Build the test statistic
% ------------------------
nXH1 = size(XH1,2);
d   = inv(XH0'*XH0)*XH0'*XH1;
r   = XH1 - XH0*d;
i   = ones(T,1);
aux = (repmat(u,1,nXH1).*r);

rX = rank(aux'*aux);
nX = size(aux,2);

c   = inv(aux'*aux)*aux'*i;
e   = i - aux*c;
SSE = sumsqr(e);

CHI2 = T - SSE;

CHI2     = ones(N,1)*CHI2;
chi2     = chi2inv(sig,nXH1);
chi2     = chi2';
isLinear = CHI2 <= chi2;
pvalue   = 1 - chi2cdf(CHI2,nXH1);