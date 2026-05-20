function out_vector = lag(in_vector, lag)
% this function takes as input a vector and returns
% as output the shift-down version of the same vector (i.e. the 2nd element of
% the new vector will have to be the 1st element of the original one, and so on).
% The two vectors must have the same size, so you must fill the first position with NaN
[r c] = size(in_vector);

% transpose the vector if you input a row vector
if r<c
    in_vector = in_vector';
end
out_vector = [(1:lag)'.*0 ; in_vector(1:end-lag,1)];
end