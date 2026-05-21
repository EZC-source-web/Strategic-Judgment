function [y_snapped, step] = snap_realized_to_bin_grid(y, endpoints)
%SNAP_REALIZED_TO_BIN_GRID Round a realization to the implied bin grid.
%
% [y_snapped, step] = SNAP_REALIZED_TO_BIN_GRID(y, endpoints) first closes
% open histogram tails with SANITIZE_HIST_BINS, then infers the grid spacing
% from finite endpoints. If the grid spacing cannot be inferred robustly, it
% falls back to 0.1.

fallback_step = 0.1;
min_reasonable_step = 1e-8;

if ~isfinite(y)
    y_snapped = NaN;
    step = fallback_step;
    return;
end

endpoints = sanitize_hist_bins(endpoints);
finite_points = endpoints(isfinite(endpoints));
finite_points = unique(sort(finite_points(:)));

if numel(finite_points) < 2
    step = fallback_step;
else
    diffs = diff(finite_points);
    diffs = diffs(isfinite(diffs) & diffs > min_reasonable_step);
    if isempty(diffs)
        step = fallback_step;
    else
        step = min(diffs);
    end
end

if ~isfinite(step) || step <= min_reasonable_step
    step = fallback_step;
end
step = round(step .* 1e12) ./ 1e12;

ratio = y ./ step;
y_snapped = sign(ratio) .* floor(abs(ratio) + 0.5 + 100 .* eps(abs(ratio))) .* step;
[nearest_endpoint, nearest_distance] = nearest_finite_endpoint(y_snapped, finite_points);
if nearest_distance <= max(min_reasonable_step, step .* 1e-8)
    y_snapped = nearest_endpoint;
end
y_snapped = double(y_snapped);
end

function [nearest_endpoint, nearest_distance] = nearest_finite_endpoint(y, finite_points)
if isempty(finite_points)
    nearest_endpoint = y;
    nearest_distance = Inf;
    return;
end
[nearest_distance, idx] = min(abs(finite_points - y));
nearest_endpoint = finite_points(idx);
end
