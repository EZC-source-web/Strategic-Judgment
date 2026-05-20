function pit = pit_from_hist(bin_edges, prob, y)
%PIT_FROM_HIST Probability integral transform from histogram densities.
%
% pit = PIT_FROM_HIST(bin_edges, prob, y) computes CDF(y) for each row of a
% histogram forecast. Within each bin, probability is spread uniformly.

if isvector(bin_edges)
    edges = bin_edges(:);
    lower = edges(1:(end - 1));
    upper = edges(2:end);
else
    lower = bin_edges(:, 1);
    upper = bin_edges(:, 2);
end

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
    if y(t) <= lower(1)
        pit(t) = 0;
    elseif y(t) >= upper(end)
        pit(t) = 1;
    else
        idx = find(y(t) >= lower & y(t) < upper, 1, 'first');
        frac = (y(t) - lower(idx)) / width(idx);
        pit(t) = cum_prob(t, idx) + frac * prob_norm(t, idx);
        pit(t) = min(max(pit(t), 0), 1);
    end
end
end
