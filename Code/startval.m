% Function to compute starting valus for a multiple-regime Smooth
% Transition Regression (STR). The algorith is based on a grid search over
% the parameters gamma and c.
% Last update: October 4, 2006.
function [alphaf,betaf,lambdaf,gammaf,cf,bestcost]=startval(y,X,W,q,m,gamma,c)

% inputs:
% ------
% y: dependent variable.
% X: regressors.
% W: dummy regressors.
% q: transition variable.
% m: number of nonlinear terms (number of regimes - 1)
% gamma: gamma values for the previous nonlinear terms.
% c: c values for the previous nonlinear terms.

% outputs:
% -------
% alphaf: starting value for alpha.
% lambdaf: starting value for lambda.
% gammaf: starting value for gamma.
% cf: starting value for c.
% bestcost: cost function evaluated at the starting point.


bestcost=999999999999999999999999;

[T,nX] = size(X);
nW     = size(W,2);

% Maximum and minimum values for gamma
% ------------------------------------
maxgamma  = 50;
mingamma  = 10;
rategamma = 1;

% Maximum and minumum values for c
% --------------------------------
minc=prctile(q,10);
maxc=prctile(q,90);
ratec=(maxc-minc)/200;
gamma(m,1) = 0;
c(m,1) = 0;
for newgamma=mingamma:rategamma:maxgamma
    for newc=minc:ratec:maxc
        gamma(m,1) = newgamma;
        c(m,1)     = newc;
        Z = [X W];
        for i=1:m
            fX(:,i) = siglog(gamma(i)*(q-c(i)));
            Z       = [Z repmat(fX(:,i),1,nX).*X];
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
            yhat   = X*alpha +  sum((fX*lambda').*X,2);
        else
            yhat   = X*alpha + W*beta + sum((fX*lambda').*X,2);
        end
        e      = y - yhat;
      	cost   = sum(e.^2)/T;
       	if cost<=bestcost
            bestcost = cost;
            gammaf   = gamma;
            cf       = c;
            alphaf   = alpha;
            betaf    = beta;
            lambdaf  = lambda;
        end
    end
end
