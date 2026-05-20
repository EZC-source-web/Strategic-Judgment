function [y,w]=sim_AR(phi0, phi1, phi2, T ,nsim, sigerr)
%This file simulate a linear AR(2) process

%Preallocate
y = zeros(T,nsim);

%Definitions
phi=[phi1; phi2];
eps = sqrt(sigerr)*randn(T,nsim);

%Simulate a Linear AR process
for i= 3 : T 
    y(i) = phi0 + [y(i-1), y(i-2)]*phi + eps(i);
end
w = [lag(y,1), lag(y,2)]'; 
u= y - phi0 - [y(i-1), y(i-2)]*phi;
y = y(3:end,1);
end