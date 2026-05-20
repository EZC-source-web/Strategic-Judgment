function [theta, eta, s, c, eta_t, h, mu, G]=sim_G_glstar1(phi0, phi1, phi2, theta0, theta1, theta2, gamma1, gamma2, y, T)
%This function build the G function of GLSTAR1 model

%Definitions
phi=[phi1; phi2];
theta=[theta1; theta2];

%Definitions for Nonlinear part
eta = phi0 + phi'*[lag(y,1), lag(y,2)]' + theta0 + theta'*[lag(y,1), lag(y,2)]';
s = lag(eta,1) ;
c = (1/T)*sum(eta) ;
eta_t = (s - repmat(c,length(s),1)) ;
                                
%Define the Stukel function (fromula 2-3)
h11 = (gamma1^(-1))*(exp(gamma1.*abs(eta)) - 1) ; 
h12 = eta ;
h13 = (-gamma1^(-1))*log(1 - gamma1.*abs(eta)) ; 

h21 = (-gamma2^(-1))*(exp(gamma2.*abs(eta)) - 1) ;
h22 = eta ;
h23 = (gamma2^(-1))*log(1 - gamma2.*abs(eta)) ; 
         
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
h = ((eta_t) <=0).*(h2') + ((eta_t) >=0).*(h1');
mu = exp(h)./(1 + exp(h));
G = (1 + exp(-h)).^(-1);
end