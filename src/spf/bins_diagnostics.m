function diag = bins_diagnostics(input_arg)
%BINS_DIAGNOSTICS Diagnose gaps, overlaps, and realized values in bin gaps.

if nargin < 1 || isempty(input_arg)
    cfg = default_config();
    realized_file = cfg.spf.realized_file;
elseif isstruct(input_arg)
    cfg = input_arg;
    realized_file = cfg.spf.realized_file;
else
    realized_file = char(input_arg);
end

if exist(realized_file, 'file') ~= 2
    error('bins_diagnostics:MissingRealizedCache', ...
        'SPF aggregate realized cache not found: %s', realized_file);
end

loaded = load(realized_file, 'spf_aggR');
if ~isfield(loaded, 'spf_aggR')
    error('bins_diagnostics:MissingVariable', ...
        'Realized cache does not contain variable "spf_aggR": %s', realized_file);
end

spf_aggR = loaded.spf_aggR;
series_diag = empty_series_diag();

for j = 1:numel(spf_aggR.series)
    s = spf_aggR.series(j);
    n_dates = numel(s.dates);
    max_gaps = NaN(n_dates, 1);
    gap_dates = false(n_dates, 1);
    nonmonotone_dates = false(n_dates, 1);
    realized_in_gap_raw = false(n_dates, 1);
    realized_in_gap_snapped = false(n_dates, 1);

    for t = 1:n_dates
        endpoints = get_endpoints(s.bin_edges_by_date{t});
        [max_gaps(t), gap_dates(t), nonmonotone_dates(t)] = gap_stats(endpoints);
        if isfield(s, 'realized_by_date') && numel(s.realized_by_date) >= t
            y_raw = get_realized_value(s.realized_by_date, t);
            realized_in_gap_raw(t) = value_in_gap(y_raw, endpoints);
            if realized_in_gap_raw(t)
                y_snapped = snap_realized_to_bin_grid(y_raw, endpoints);
                realized_in_gap_snapped(t) = value_in_gap(y_snapped, endpoints);
            end
        end
    end

    finite_gaps = max_gaps(isfinite(max_gaps));
    if isempty(finite_gaps)
        median_gap = NaN;
        max_gap = NaN;
    else
        median_gap = median(finite_gaps);
        max_gap = max(finite_gaps);
    end

    series_diag(end + 1) = struct( ... %#ok<AGROW>
        'name', s.name, ...
        'horizon', s.horizon, ...
        'dates', s.dates(:), ...
        'max_gap_by_date', max_gaps(:), ...
        'median_gap', median_gap, ...
        'max_gap', max_gap, ...
        'dates_with_gap_count', sum(gap_dates), ...
        'nonmonotone_count', sum(nonmonotone_dates), ...
        'realized_in_gap_raw_count', sum(realized_in_gap_raw), ...
        'realized_in_gap_snapped_count', sum(realized_in_gap_snapped), ...
        'realized_in_gap_raw_dates', s.dates(realized_in_gap_raw), ...
        'realized_in_gap_snapped_dates', s.dates(realized_in_gap_snapped), ...
        'realized_in_gap_count', sum(realized_in_gap_snapped), ...
        'realized_in_gap_dates', s.dates(realized_in_gap_snapped));
end

diag = struct();
diag.meta = struct();
diag.meta.status = 'ok';
diag.meta.source_file = realized_file;
diag.meta.gap_tolerance = 1e-8;
diag.meta.series_count = numel(series_diag);
diag.series = series_diag;
end

function out = empty_series_diag()
out = struct('name', {}, 'horizon', {}, 'dates', {}, ...
    'max_gap_by_date', {}, 'median_gap', {}, 'max_gap', {}, ...
    'dates_with_gap_count', {}, 'nonmonotone_count', {}, ...
    'realized_in_gap_raw_count', {}, 'realized_in_gap_snapped_count', {}, ...
    'realized_in_gap_raw_dates', {}, 'realized_in_gap_snapped_dates', {}, ...
    'realized_in_gap_count', {}, 'realized_in_gap_dates', {});
end

function endpoints = get_endpoints(bin_edges)
if isvector(bin_edges)
    edges = bin_edges(:);
    endpoints = [edges(1:(end - 1)), edges(2:end)];
else
    endpoints = bin_edges;
end
end

function [max_gap, has_gap, nonmonotone] = gap_stats(endpoints)
tol = 1e-8;
if isempty(endpoints) || size(endpoints, 2) ~= 2
    max_gap = NaN;
    has_gap = false;
    nonmonotone = true;
    return;
end

lower = endpoints(:, 1);
upper = endpoints(:, 2);
width_bad = any(~isfinite(upper - lower) & ~(isinf(lower) | isinf(upper))) || ...
    any(lower >= upper);
adjacent_gap = lower(2:end) - upper(1:(end - 1));
finite_adjacent_gap = adjacent_gap(isfinite(adjacent_gap));
if isempty(finite_adjacent_gap)
    max_gap = 0;
else
    max_gap = max([0; finite_adjacent_gap(:)]);
end
has_gap = max_gap > tol;
nonmonotone = width_bad || any(finite_adjacent_gap < -tol);
end

function y = get_realized_value(realized_by_date, idx)
if iscell(realized_by_date)
    y = realized_by_date{idx};
else
    y = realized_by_date(idx);
end
if isempty(y)
    y = NaN;
else
    y = y(1);
end
end

function tf = value_in_gap(y, endpoints)
tf = false;
if ~isfinite(y) || isempty(endpoints) || size(endpoints, 1) < 2
    return;
end
lower = endpoints(:, 1);
upper = endpoints(:, 2);
tol = 1e-8;
for i = 1:(numel(upper) - 1)
    if isfinite(upper(i)) && isfinite(lower(i + 1)) && lower(i + 1) > upper(i)
        if y > upper(i) + tol && y < lower(i + 1) - tol
            tf = true;
            return;
        end
    end
end
end
