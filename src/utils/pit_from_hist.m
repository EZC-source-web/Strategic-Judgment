function pit = pit_from_hist(bin_edges, prob, y)
%PIT_FROM_HIST Probability integral transform from histogram densities.
%
% pit = PIT_FROM_HIST(bin_edges, prob, y) computes CDF(y) for each row of a
% histogram forecast. Within each bin, probability is spread uniformly.

if isvector(bin_edges)
    edges = bin_edges(:);
    endpoints = [edges(1:(end - 1)), edges(2:end)];
else
    endpoints = bin_edges(:, 1:2);
end

if any(isinf(endpoints(:)))
    [endpoints, sanitize_info] = sanitize_hist_bins(endpoints);
    for j = 1:numel(sanitize_info.messages)
        warning('pit_from_hist:SanitizedOpenBins', '%s', ...
            sanitize_info.messages{j});
    end
end

lower = endpoints(:, 1);
upper = endpoints(:, 2);

if size(prob, 2) ~= numel(lower)
    error('pit_from_hist:DimensionMismatch', ...
        'Probability columns must match the number of bins.');
end

y = y(:);
if size(prob, 1) ~= numel(y)
    error('pit_from_hist:DimensionMismatch', ...
        'Probability rows must match the number of realizations.');
end

width = upper - lower;
if any(~isfinite(width)) || any(width <= 0)
    error('pit_from_hist:InvalidBins', ...
        'Bins must be finite and strictly increasing.');
end

row_sum = sum(prob, 2, 'omitnan');
ok = row_sum > 0 & isfinite(row_sum);
prob_norm = prob;
prob_norm(ok, :) = bsxfun(@rdivide, prob(ok, :), row_sum(ok));

pit = NaN(numel(y), 1);
cum_prob = [zeros(size(prob_norm, 1), 1), cumsum(prob_norm, 2)];
snapped_count = 0;
still_missing_count = 0;

for t = 1:numel(y)
    if ~ok(t) || ~isfinite(y(t))
        continue;
    end

    y_eval = y(t);
    idx = find_bin_index(y_eval, lower, upper);

    if isempty(idx)
        y_snapped = snap_realized_to_bin_grid(y_eval, endpoints);
        idx = find_bin_index(y_snapped, lower, upper);
        if ~isempty(idx)
            y_eval = y_snapped;
            snapped_count = snapped_count + 1;
        else
            still_missing_count = still_missing_count + 1;
            continue;
        end
    end

    y_eval = min(max(y_eval, lower(idx)), upper(idx));
    frac = (y_eval - lower(idx)) / width(idx);
    pit(t) = cum_prob(t, idx) + frac * prob_norm(t, idx);
    pit(t) = min(max(pit(t), 0), 1);
end

if snapped_count > 0
    warning('pit_from_hist:SnappedRealizations', ...
        'Snapped %d realizations to the implied histogram bin grid.', snapped_count);
end
if still_missing_count > 0
    warning('pit_from_hist:RealizationOutsideBins', ...
        ['%d realizations remained outside histogram support or in bin gaps ' ...
        'after snapping; returned NaN.'], still_missing_count);
end
end

function idx = find_bin_index(y, lower, upper)
tol = 1e-8;
idx = find(y >= lower - tol & (y < upper | abs(y - upper) <= tol), 1, 'first');
if isempty(idx) && y == upper(end)
    idx = numel(upper);
end
end
