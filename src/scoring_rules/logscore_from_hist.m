function [log_score, density_at_y, stats] = logscore_from_hist(bin_edges, prob, y, min_density)
%LOGSCORE_FROM_HIST Log predictive density score from histogram probabilities.
%
% [log_score, density_at_y, stats] = LOGSCORE_FROM_HIST(bin_edges, prob, y)
% evaluates the log density at realizations y when forecasts are represented
% as histogram bin probabilities. The function is intentionally silent;
% callers can log stats.
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

stats = empty_stats();

if isvector(bin_edges)
    edges = bin_edges(:);
    endpoints = [edges(1:(end - 1)), edges(2:end)];
else
    endpoints = bin_edges(:, 1:2);
end

open_ended = any(isinf(endpoints(:)));
if open_ended
    stats.sanitized_open_bins = true;
    endpoints = sanitize_hist_bins(endpoints);
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
snapped_count = 0;
still_missing_count = 0;

for t = 1:numel(y)
    if ~isfinite(y(t)) || ~ok(t)
        density_at_y(t) = NaN;
        continue;
    end
    y_eval = y(t);
    idx = find_bin_index(y_eval, lower, upper, open_ended);
    if isempty(idx)
        y_snapped = snap_realized_to_bin_grid(y_eval, endpoints);
        idx = find_bin_index(y_snapped, lower, upper, open_ended);
        if ~isempty(idx)
            y_eval = y_snapped; %#ok<NASGU>
            snapped_count = snapped_count + 1;
        else
            still_missing_count = still_missing_count + 1;
        end
    end

    if ~isempty(idx)
        density_at_y(t) = max(density(t, idx), min_density);
    end
end

if snapped_count > 0
    stats.snapped_count = snapped_count;
end
if still_missing_count > 0
    stats.still_missing_count = still_missing_count;
end

log_score = log(density_at_y);
end

function stats = empty_stats()
stats = struct();
stats.sanitized_open_bins = false;
stats.snapped_count = 0;
stats.still_missing_count = 0;
end

function idx = find_bin_index(y, lower, upper, open_ended)
tol = 1e-8;
if open_ended && y < lower(1) - tol
    idx = 1;
    return;
end
if open_ended && y > upper(end) + tol
    idx = numel(upper);
    return;
end
idx = find(y >= lower - tol & (y < upper | abs(y - upper) <= tol), 1, 'first');
if isempty(idx) && y == upper(end)
    idx = numel(upper);
end
end
