function out = lstar_linearity_test(y, p, d, include_const)
%LSTAR_LINEARITY_TEST Terasvirta/Luukkonen STAR linearity test.
%
% out = LSTAR_LINEARITY_TEST(y, p, d, include_const) tests a linear AR(p)
% null against a smooth-transition autoregressive alternative using the
% third-order Taylor approximation of the transition function.
%
% Inputs
%   y             T-by-1 time series.
%   p             Autoregressive lag order.
%   d             Transition delay. The transition variable is y_{t-d}.
%   include_const Include an intercept in the null regression.
%
% Output
%   out is a struct containing F and LM statistics, p-values, degrees of
%   freedom, SSRs, coefficients, residuals, and basic diagnostics.
%
% Notes
%   The null regression is y_t on AR lags. The auxiliary regression augments
%   the null with y_{t-j} * z_t^k for j=1,...,p and k=1,2,3, where z_t is the
%   centered and scaled transition variable y_{t-d}. The restriction count is
%   computed from the rank difference between the unrestricted and restricted
%   designs, making the test robust to collinearity in small samples.

if nargin < 4 || isempty(include_const)
    include_const = true;
end

validate_inputs(y, p, d);
y = y(:);

max_lag = max(p, d);
T = numel(y);
dep = y((max_lag + 1):T);

lag_block = lagmat(y, 1:p);
X_lags = lag_block((max_lag + 1):T, :);
z = lagmat(y, d);
z = z((max_lag + 1):T, 1);

valid = isfinite(dep) & all(isfinite(X_lags), 2) & isfinite(z);
dep = dep(valid);
X_lags = X_lags(valid, :);
z = z(valid);

if numel(dep) <= (4 * p + double(include_const))
    error('lstar_linearity_test:TooFewObservations', ...
        'Too few observations for p=%d and d=%d.', p, d);
end

z_std = std(z);
if z_std > 0
    z = (z - mean(z)) ./ z_std;
else
    z = z - mean(z);
end

if include_const
    X0 = [ones(numel(dep), 1), X_lags];
else
    X0 = X_lags;
end

X_aux = [];
for k = 1:3
    X_aux = [X_aux, bsxfun(@times, X_lags, z .^ k)]; %#ok<AGROW>
end
X1 = [X0, X_aux];

fit0 = ols_fit(dep, X0);
fit1 = ols_fit(dep, X1);

n = numel(dep);
df_num = fit1.rank - fit0.rank;
df_den = n - fit1.rank;

if df_num <= 0 || df_den <= 0
    error('lstar_linearity_test:InvalidDegreesOfFreedom', ...
        'Invalid degrees of freedom: numerator=%d, denominator=%d.', ...
        df_num, df_den);
end

ssr_gain = max(fit0.ssr - fit1.ssr, 0);
F_stat = (ssr_gain / df_num) / (fit1.ssr / df_den);
LM_stat = n * ssr_gain / fit0.ssr;

out = struct();
out.F_stat = F_stat;
out.F_pvalue = 1 - local_fcdf(F_stat, df_num, df_den);
out.LM_stat = LM_stat;
out.LM_pvalue = 1 - local_chi2cdf(LM_stat, df_num);
out.df = struct('num', df_num, 'den', df_den, 'lm', df_num);

out.nobs = n;
out.p = p;
out.d = d;
out.include_const = logical(include_const);

out.ssr0 = fit0.ssr;
out.ssr1 = fit1.ssr;
out.r2_null = fit0.r2;
out.r2_auxiliary = fit1.r2;
out.sigma2_null = fit0.sigma2;
out.sigma2_auxiliary = fit1.sigma2;
out.rank_null = fit0.rank;
out.rank_auxiliary = fit1.rank;
out.condition_null = fit0.condition_number;
out.condition_auxiliary = fit1.condition_number;

out.beta_null = fit0.beta;
out.beta_auxiliary = fit1.beta;
out.resid_null = fit0.resid;
out.resid_auxiliary = fit1.resid;
out.design = struct();
out.design.null_columns = size(X0, 2);
out.design.auxiliary_columns = size(X1, 2);
out.design.auxiliary_terms = {'lag*z', 'lag*z^2', 'lag*z^3'};
end

function validate_inputs(y, p, d)
if nargin < 3
    error('lstar_linearity_test:InvalidInput', ...
        'Inputs y, p, and d are required.');
end
if isempty(y) || ~isnumeric(y) || ~isvector(y)
    error('lstar_linearity_test:InvalidY', 'y must be a numeric vector.');
end
if ~isscalar(p) || p < 1 || fix(p) ~= p
    error('lstar_linearity_test:InvalidLagOrder', ...
        'p must be a positive integer.');
end
if ~isscalar(d) || d < 1 || fix(d) ~= d
    error('lstar_linearity_test:InvalidDelay', ...
        'd must be a positive integer.');
end
end

function fit = ols_fit(y, X)
beta = X \ y;
resid = y - X * beta;
ssr = sum(resid .^ 2);
tss = sum((y - mean(y)) .^ 2);
rank_x = rank(X);
df_resid = numel(y) - rank_x;

fit = struct();
fit.beta = beta;
fit.resid = resid;
fit.ssr = ssr;
fit.rank = rank_x;
fit.sigma2 = ssr / df_resid;
if tss > 0
    fit.r2 = 1 - ssr / tss;
else
    fit.r2 = NaN;
end
fit.condition_number = cond(X);
end

function p = local_fcdf(x, df1, df2)
if x <= 0
    p = 0;
    return;
end
z = (df1 * x) / (df1 * x + df2);
p = betainc(z, df1 / 2, df2 / 2);
end

function p = local_chi2cdf(x, df)
if x <= 0
    p = 0;
    return;
end
p = gammainc(x / 2, df / 2);
end
