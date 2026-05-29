function model = fit_arx(y, p, x, include_const)
%FIT_ARX Estimate an ARX model by OLS.
%
% model = FIT_ARX(y, p, x, include_const) estimates
%
%   y_t = c + a_1 y_{t-1} + ... + a_p y_{t-p} + b'x_t + e_t
%
% using all rows with finite y, lags, and regressors. x can be empty for a
% plain AR(p). The function uses only base MATLAB routines.

if nargin < 3
    x = [];
end
if nargin < 4 || isempty(include_const)
    include_const = true;
end

y = double(y(:));
if isempty(x)
    x = zeros(numel(y), 0);
else
    x = double(x);
    if size(x, 1) ~= numel(y)
        error('fit_arx:DimensionMismatch', ...
            'x must have the same number of rows as y.');
    end
end

if numel(y) <= p
    error('fit_arx:TooFewObservations', ...
        'Need more observations than the lag order.');
end

n = numel(y);
rows = (p + 1):n;
X = [];
if include_const
    X = ones(numel(rows), 1);
end

for lag = 1:p
    X = [X, y(rows - lag)]; %#ok<AGROW>
end
if ~isempty(x)
    X = [X, x(rows, :)]; %#ok<AGROW>
end
y_reg = y(rows);

valid = isfinite(y_reg) & all(isfinite(X), 2);
X = X(valid, :);
y_reg = y_reg(valid);

if size(X, 1) <= size(X, 2)
    error('fit_arx:TooFewUsableObservations', ...
        'Not enough usable observations after lag/exogenous alignment.');
end

beta = X \ y_reg;
fitted = X * beta;
residuals = y_reg - fitted;

model = struct();
model.p = p;
model.include_const = include_const;
model.nx = size(x, 2);
model.beta = beta;
model.residuals = residuals(:);
model.sigma2 = sum(residuals .^ 2) / max(size(X, 1) - size(X, 2), 1);
model.nobs = size(X, 1);
model.df = max(size(X, 1) - size(X, 2), 0);
model.design_rank = rank(X);
model.x_pool = x(all(isfinite(x), 2), :);
end
