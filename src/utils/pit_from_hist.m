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

for t = 1:numel(y)
    if ~ok(t) || ~isfinite(y(t))
        continue;
    end

    idx = find(y(t) >= lower & y(t) < upper, 1, 'first');
    if isempty(idx) && y(t) == upper(end)
        idx = numel(upper);
    end

    if isempty(idx)
        warning('pit_from_hist:RealizationOutsideBins', ...
            ['Realization at row %d is outside histogram support or falls ' ...
            'in a bin gap; returning NaN.'], t);
        continue;
    end

    frac = (y(t) - lower(idx)) / width(idx);
    pit(t) = cum_prob(t, idx) + frac * prob_norm(t, idx);
    pit(t) = min(max(pit(t), 0), 1);
end
end
