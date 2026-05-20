%% Script: Illustrate use of FanChart function

clear all; clc;

% Generate artifical history and forecasts
T=100; % number of historical observations
H=12; % number of forecast periods
fore=randn(H,1000);
for h=1:H
   fore(h,:)=(fore(h,:).*h)./1000; 
end
hist=.1.*randn(T,1);

% Call fan chart function
FanChart(fore,hist,'Jun2009',6);