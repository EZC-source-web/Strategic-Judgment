
% This function computes the vec of a matrix.
%	
%      |1  2  3|
% If A=|4  5  6|
%      |7  8  9|
%
%	        |1|
%	        |4|
%	        |7|
%	        |2|
% hence, vec(A)=|5|
%	        |8|
%	        |3|
%	        |6|
%	        |9|
%
% Last update: February 5, 2010                                   
	
function X = vec(A)

	[m,n] = size(A);
	X     = reshape(A,m*n,1);