function [y, phi, theta, eps, eta, s, c, eta_t, h, mu, G, u, w,...
    sigma2_hat, sigma_hat, bounds] = sim_GLSTAR1(phi0, phi1, phi2, theta0, theta1, theta2, gamma1, gamma2, T, sigerr)
%This function simulate a time series following the Generalized Logistic
%Smooth Transition function by EZC
%
%The process is assumed having an AR(2) dynamics
%
%

%Preallocate
y = zeros(T,1);

%Definitions
phi=[phi1; phi2];
theta=[theta1; theta2];
eps = sqrt(sigerr)*randn(T,1);

%Simulate a Linear AR process
for i= 3 : T    
    y(i) = phi0 + [y(i-1), y(i-2)]*phi + eps(i);
end
w = [lag(y,1), lag(y,2)]'; 


%Definitions for Nonlinear part
eta = phi0 + w'*phi + theta0 + w'*theta ;
s = lag(eta,1);
c = (1/T).*eta;
eta_t = (s - c);
                                

%Define the Stukel function (fromula 2-3)
h11 = (gamma1^(-1)).*(exp(gamma1*abs(eta)) - 1) ; 
h12 = eta;
h13 = (-gamma1^(-1))*log(1 - gamma1*abs(eta)) ; 

h21 = (-gamma2^(-1)).*(exp(gamma2*abs(eta)) - 1) ;
h22 = eta ;
h23 = (gamma2^(-1))*log(1 - gamma2*abs(eta)) ; 
         
if gamma1 > 0
    h1 = h11;
elseif gamma1 == 0
    h1 = h12;
else h1 = h13;
end

if gamma2 > 0
   h2 = h21;
elseif gamma2 == 0
    h2 = h22 ;
else h2 = h23;
end

%Define: h_gamma, mu_gamma and G
h = ((eta_t) <=0).*(h2) + ((eta_t) >=0).*(h1);
mu = exp(h)./(1 + exp(h));
G = (1 + exp(-h)).^(-1);

%Simulate the GSTAR(1) model and compute estimated residuals, variance of
%estimated residuals and sd:
for i= 3 : T
    y(i) = y(i) + theta0 + [G(i-1), G(i-2)]*theta + eps(i);
end
u = y - phi0 - phi1.*y(i-1) - phi2.*y(i-2) - theta0 - theta1.*G(i-1) - theta2.*G(i-2);   %compute the estimated residuals
sigma2_hat = (1/T)*sum((u.^2));                                                          %compute the variance of the residuals 
sigma_hat = sqrt(sigma2_hat);                                                           %compute the SD of the residuals

% Drop the first p observations
y = y(3:T,1);
s = s(3:T,1);
c = c(3:T,1);
eps = eps(3:T,1);
eta=eta(3:T,1);
eta_t = eta_t(3:T,1);
h = h(3:T,1);
mu = mu(3:T,1);
G = G(3:T,1);
u = u(3:T,1);
w=w(:,3:T);


[ACF, Lags, Bounds] = autocorr(y,5,2,2); 
bounds = repmat(Bounds, 1,20);
 
%%%%%%%%%%%%%%%%
%RESULTS
%%%%%%%%%%%%%%%%
figure(1)

subplot(2,3,1)
plot(y);
xlabel('T')                          
ylabel('y')                       
title('Simulated GLSTAR1')

subplot(2,3,2)
plot(u);
xlabel('T')                          
ylabel('u')                       
title('Estimated Residuals')

subplot(2,3,3)
plot(sort(s), sort(G))
xlabel('\Delta y_t')                          
ylabel('G')                       
title('Transition Function versus transition variable')

subplot(2,3,4)
plot(1:T-length(theta), G)
xlabel('T')                          
ylabel('G')                       
title('Transition Function versus time')

subplot(2,3,5)
qqplot(y);
xlabel('T')                          
ylabel('y') 
title('QQ plot')

subplot(2,3,6)
stem(Lags, ACF)
xlabel('Lags')                          
ylabel('Sample Autocorrelation') 
title('Sample ACF')

%subplot(2,3,6)
%cdfplot(y)
%hold on
%x = -10:0.1:10;
%f = normcdf(x,0,1);
%plot(x,f,'m')
%legend('Empirical','Theoretical', 2)

end