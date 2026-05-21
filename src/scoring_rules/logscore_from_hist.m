function [log_score, density_at_y] = logscore_from_hist(bin_edges, prob, y, min_density)
%LOGSCORE_FROM_HIST Log predictive density score from histogram probabilities.
%
% [log_score, density_at_y] = LOGSCORE_FROM_HIST(bin_edges, prob, y)
% evaluates the log density at realizations y when forecasts are represented
% as histogram bin probabilities.
%
% Inputs
%   bin_edges  Either K+1 edges or K-by-2 lower/upper endpoints.
%   prob       T-by-K matrix of bin probabilities.
%   y          T-by-1 realized values.
%   min_density Optional density floor. Default is 1e-12.
%
% Output
%   log_score    T-by-1 log predictive density values.
%   density_at_y T-by-1 density values used in the log score.

if nargin < 4 || isempty(min_density)
    min_density = 1e-12;
end

if isvector(bin_edges)
    edges = bin_edges(:);
    endpoints = [edges(1:(end - 1)), edges(2:end)];
else
    endpoints = bin_edges(:, 1:2);
end

if any(isinf(endpoints(:)))
    [endpoints, sanitize_info] = sanitize_hist_bins(endpoints);
    for j = 1:numel(sanitize_info.messages)
        warning('logscore_from_hist:SanitizedOpenBins', '%s', ...
            sanitize_info.messages{j});
    end
end

lower = endpoints(:, 1);
upper = endpoints(:, 2);

if size(prob, 2) ~= numel(lower)
    error('logscore_from_hist:DimensionMismatch', ...
        'Probability columns must match the number of bins.');
end

y = y(:);
if size(prob, 1) ~= numel(y)
    error('logscore_from_hist:DimensionMismatch', ...
        'Probability rows must match the number of realizations.');
end

width = upper - lower;
if any(~isfinite(width)) || any(width <= 0)
    error('logscore_from_hist:InvalidBins', ...
        'Bins must be finite and strictly increasing.');
end

row_sum = sum(prob, 2, 'omitnan');
ok = row_sum > 0 & isfinite(row_sum);
prob_norm = prob;
prob_norm(ok, :) = bsxfun(@rdivide, prob(ok, :), row_sum(ok));

density = bsxfun(@rdivide, prob_norm, width(:)');
density_at_y = NaN(numel(y), 1);

for t = 1:numel(y)
    if ~isfinite(y(t)) || ~ok(t)
        density_at_y(t) = NaN;
        continue;
    end
    idx = find(y(t) >= lower & y(t) < upper, 1, 'first');
    if isempty(idx) && y(t) == upper(end)
        idx = numel(upper);
    end
    if ~isempty(idx)
        density_at_y(t) = max(density(t, idx), min_density);
    else
        warning('logscore_from_hist:RealizationOutsideBins', ...
            ['Realization at row %d is outside histogram support or falls ' ...
            'in a bin gap; returning NaN.'], t);
    end
end

log_score = log(density_at_y);
end
