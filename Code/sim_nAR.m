function [y, eps, phi, w, u_l] = sim_nAR(phi0, phi1, phi2, T, sigerr)

%Preallocate
y = zeros(T,1);

%Definitions
phi=[phi1; phi2];
eps = sqrt(sigerr)*randn(T,1);

%Simulate a Linear AR process
for i= 3 : T 
    y(i) = phi0 + [y(i-1), y(i-2)]*phi + eps(i) ;
    u_l = y - phi0 - [y(i-1), y(i-2)]*phi;
end
y = y(3:end,1);
w = [mlag(y,1), mlag(y,2)]'; 

end
