% Estimation of the multiple-Regime STAR model
% Last update: February 5, 2010.

function [yhat,ehat,alpha,beta,lambda,gamma,c,se,G,fX,pvalue] = mrstar(y,X,W,q,T,nX,nW,M,rob,flag,sig)
                                                     
% inputs:
% ------
% y: dependent variable.
% X: regressors including a constant.
% W: dummy explanatory variables or other variables with constant coefficients. 
% q: transition variable.
% M: number of fixed regimes. If M is empty, than the function will determine the number of regimes by a sequential testing procedure.
% rob: dummy variable indicating if robust tests (against non-normality and heteroskedasticity) should be used or not. 
% flag: dummy variable indicating if q belongs to X.
% sig: significance level of the tests.

% outputs:
% -------
% yhat: fitted values.
% ehat: residuals.
% alpha: linear parameters.
% beta: fixed parameters.
% lambda: nonlinear parameters.
% gamma: slope parameters.
% c: location parameters.

% Linearity testing
% -----------------
if isempty(M)==1
    iq = size(q,2);
    isLinear  = NaN*ones(iq,1);
    pvalue_lt = NaN*ones(iq,1);
    if rob == 0
        % non-robust linearity test
        for i=1:iq
            [isLinear(i,1),pvalue_lt(i,1)] = ltest(y,X,W,q(:,i)/std(q(:,i)),flag,sig,1);
        end
    else
        % robust linearity test
        for i=1:iq
            [isLinear(i,1),pvalue_lt(i,1)] = ltest_rob(y,X,W,q(:,i)/std(q(:,i)),flag,sig,1);
        end
    end
    imin = find(pvalue_lt==min(pvalue_lt));
    q = q(:,imin)/std(q(:,imin));

    increase = 1 - isLinear(imin);

    % initial conditions
    if increase == 1
        gamma_0 = [];
        c_0     = [];
    end

    % Linear model
    % ------------
    XX           = [X W];
    b            = inv(XX'*XX)*XX'*y;
    yhat_linear  = XX*b;
    ehat_linear  = y - yhat_linear; 
    sigma_linear = std(ehat_linear);
    se_linear    = sigma_linear*sqrt(diag(inv(XX'*XX)));

    m = 0; % number of nonlinear terms in the model.
    while increase==1
        m = m + 1;
        [alpha,lambda,beta,gamma,c,fX,yhat,ehat,G] = parestlm(y,X,W,q,T,nX,nW,m,gamma_0,c_0);
        L(m)=var(ehat);
        if rob==0
            [increase,pvalue(m)] = testnonlinear(X,q,ehat,G,flag,1-(1-sig)/(2^m),1);
        else
            [increase,pvalue(m)] = testnonlinear_rob(X,q,ehat,G,flag,1-(1-sig)/(2^m),1);
        end
        gamma_0 = gamma;
        c_0 = c;
    end
    if m > 0
        Z = [X W];
        for i=1:m
            if gamma(i)<0
                gamma(i)=-gamma(i);
            end
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
        sigma  = std(ehat);
        se     = sigma*sqrt(diag(pinv(G'*G)));
    else
        yhat   =  yhat_linear;
        ehat   =  ehat_linear;
        alpha  =  b(1:end-nW);
        lambda = [];
        gamma  = [];
        fX     = [];
        c      = [];
        beta   = b(end-nW+1:end);
        pvalue = [];
        G      = [];
        se     = se_linear;
    end
else
    gamma_0 = [];
    c_0     = [];
    for m=1:M
        [alpha,lambda,beta,gamma,c,fX,yhat,ehat,G] = parestlm(y,X,W,q,T,nX,nW,m,gamma_0,c_0);
       
        gamma_0 = gamma;
        c_0 = c;
    end
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
    sigma  = std(ehat);
    se     = sigma*sqrt(diag(pinv(G'*G)));
end