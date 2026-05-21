function [endpoints, info] = sanitize_hist_bins(bin_endpoints)
%SANITIZE_HIST_BINS Replace open-ended histogram tails with finite endpoints.
%
% [endpoints, info] = SANITIZE_HIST_BINS(bin_endpoints) accepts either K-by-2
% lower/upper endpoints or a K+1 edge vector. It returns K-by-2 endpoints.
% Interior bins are never modified. If the first lower endpoint is -Inf, it is
% replaced by upper(1)-tail_width. If the last upper endpoint is +Inf, it is
% replaced by lower(end)+tail_width. Tail widths use the adjacent finite bin
% width when available, otherwise the median finite bin width.

if isvector(bin_endpoints)
    edges = bin_endpoints(:);
    endpoints = [edges(1:(end - 1)), edges(2:end)];
else
    endpoints = bin_endpoints;
end

if size(endpoints, 2) ~= 2
    error('sanitize_hist_bins:InvalidInput', ...
        'bin_endpoints must be a K-by-2 matrix or a K+1 edge vector.');
end

endpoints = double(endpoints);
lower = endpoints(:, 1);
upper = endpoints(:, 2);

finite_width = upper - lower;
finite_width = finite_width(isfinite(finite_width) & finite_width > 0);
median_width = NaN;
if ~isempty(finite_width)
    median_width = median(finite_width);
end

info = struct();
info.closed_lower_tail = false;
info.closed_upper_tail = false;
info.lower_tail_width = NaN;
info.upper_tail_width = NaN;
info.messages = {};

if ~isempty(endpoints) && isinf(lower(1)) && lower(1) < 0
    width = adjacent_width(endpoints, 2, median_width);
    endpoints(1, 1) = upper(1) - width;
    info.closed_lower_tail = true;
    info.lower_tail_width = width;
    info.messages{end + 1} = sprintf( ...
        'Closed lower -Inf tail using width %.12g.', width);
end

if ~isempty(endpoints) && isinf(upper(end)) && upper(end) > 0
    width = adjacent_width(endpoints, size(endpoints, 1) - 1, median_width);
    endpoints(end, 2) = lower(end) + width;
    info.closed_upper_tail = true;
    info.upper_tail_width = width;
    info.messages{end + 1} = sprintf( ...
        'Closed upper +Inf tail using width %.12g.', width);
end
end

function width = adjacent_width(endpoints, row_idx, fallback_width)
width = NaN;
if row_idx >= 1 && row_idx <= size(endpoints, 1)
    candidate = endpoints(row_idx, 2) - endpoints(row_idx, 1);
    if isfinite(candidate) && candidate > 0
        width = candidate;
    end
end
if ~isfinite(width) || width <= 0
    width = fallback_width;
end
if ~isfinite(width) || width <= 0
    error('sanitize_hist_bins:CannotInferTailWidth', ...
        'Could not infer a finite positive width for an open-ended tail.');
end
end
