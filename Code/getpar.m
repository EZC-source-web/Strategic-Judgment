function [gamma,c]=getpar(PSI) 

n     = size(PSI,1);
gamma = PSI(1:n/2);
c     = PSI(n/2+1:n);