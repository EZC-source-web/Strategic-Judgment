% Test for remaining nonlinearity.
% The test is based on the third-order Taylor series expansion of the
% logistic function arounf the null hypothesis.
% Last update: October 4, 2006.

function [increase,pvalue] = testnonlinear_rob(X,q,e,G,flag,sig,N)

% inputs:
% ------
% X: regressors, including a constant.
% W: regressors with fixed coefficients.
% q: transition variable.
% e: residuals estimated under the null.
% G: estimated gradient under the null.
% flag: dummy variable indicating if q belongs to X (flag = 1) or not (flag = 0).
% sig: significance level(s).
% N: dimension of sig.

% outputs:
% -------
% increase: dummy variable indicating if the model should be augmented or not.
% pvalue: p-value of the linearity test. 

[T,nX] = size(X);

nG    = size(G,2);
normG = norm(G'*e);

if normG>1e-4
    rG = rank(G'*G);
    if rG < nG
        [PC,GPCA,lambda] = princomp(G);
        lambda           = cumsum(lambda./sum(lambda));
        indmin           = min(find(lambda>0.99999));
        GPCA             = (PC*G')';
        GPCA             = GPCA(:,1:indmin);
        b                = inv(GPCA'*GPCA)*GPCA'*e;
        u                = e - GPCA*b;
        XH0              = GPCA;
    else
        b   = inv(G'*G)*G'*e;
        u   = e - G*b;
        XH0 = G;
    end
else
    u = e;
    rG = rank(G'*G);
    if rG < nG
        [PC,GPCA,lambda] = princomp(G);
        lambda           = cumsum(lambda./sum(lambda));
        indmin           = min(find(lambda>0.99999));
		GPCA             = (PC*G')';
        GPCA             = GPCA(:,1:indmin);
        XH0              = GPCA;
    else
        XH0 = G;
   end
end

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
nXH1 = size(XH1,2);
d   = inv(XH0'*XH0)*XH0'*XH1;
r   = XH1 - XH0*d;
i   = ones(T,1);
aux = (repmat(u,1,nXH1).*r);

c   = pinv(aux'*aux)*aux'*i;
v   = i - aux*c;
SSE = sumsqr(v);

% Compute the test statistic
% --------------------------
SSE0 = sumsqr(i);

CHI2 = T*(SSE0-SSE)/SSE0;

CHI2     = ones(N,1)*CHI2;
chi2     = chi2inv(sig,nXH1);
chi2     = chi2';
increase = 1 - (CHI2 <= chi2);
pvalue   = 1 - chi2cdf(CHI2,nXH1);