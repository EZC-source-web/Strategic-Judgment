function L = lagmat(x, lags)
%LAGMAT Construct lagged columns without requiring a toolbox.
%
% L = LAGMAT(x, lags) returns a matrix with the same number of rows as x.
% For each lag in lags, the corresponding block contains x shifted down by
% that lag and padded with NaN at the top. If x is T-by-K and lags has M
% elements, L is T-by-(K*M). Blocks are ordered as lags(:)'.

if nargin < 2
    error('lagmat:InvalidInput', 'Both x and lags are required.');
end

if isempty(x)
    L = [];
    return;
end

if isvector(x)
    x = x(:);
end

lags = lags(:)';
if any(lags < 0) || any(fix(lags) ~= lags)
    error('lagmat:InvalidLag', 'Lags must be non-negative integers.');
end

[T, K] = size(x);
L = NaN(T, K * numel(lags));

for i = 1:numel(lags)
    lag = lags(i);
    cols = (i - 1) * K + (1:K);
    if lag == 0
        L(:, cols) = x;
    elseif lag < T
        L((lag + 1):T, cols) = x(1:(T - lag), :);
    end
end
end
