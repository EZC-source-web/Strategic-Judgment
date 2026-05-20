% Test for remaining nonlinearity.
% The test is based on the third-order Taylor series expansion of the
% logistic function arounf the null hypothesis.
% Last update: February 5, 2010.

function [increase,pvalue] = testnonlinear(X,q,e,G,flag,sig,N)

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

SSE0 = sumsqr(u);

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
v   = u - Z*c;
SSE = sumsqr(v);

% Compute the test statistic
% --------------------------
nXH0 = size(XH0,2);
nXH1 = size(XH1,2);

F = ((SSE0-SSE)/nXH1)/(SSE/(T-nXH0-nXH1));
F = ones(N,1)*F;
f = finv(sig,nXH1,T-nXH0-nXH1);
f = f';
increase = 1-(F <= f);
pvalue = 1-fcdf(F,nXH1,T-nXH0-nXH1);