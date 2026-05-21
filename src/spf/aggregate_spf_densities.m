function spf_agg = aggregate_spf_densities(input_arg, cfg)
%AGGREGATE_SPF_DENSITIES Build consensus SPF densities by date and horizon.
%
% spf_agg = AGGREGATE_SPF_DENSITIES(cfg) loads cfg.spf.standardized_file.
% spf_agg = AGGREGATE_SPF_DENSITIES(cache_file) loads the given cache file.
%
% The input cache is expected to contain the individual-response struct spf
% produced by parse_spf_densities. For each mapped series name and horizon,
% this function averages individual probabilities date by date. If a date
% contains responses on different bin grids, it keeps the modal bin grid and
% records the discarded share in bins_mismatch_rate.

if nargin < 1 || isempty(input_arg)
    cfg = default_config();
    cache_file = cfg.spf.standardized_file;
elseif isstruct(input_arg)
    cfg = input_arg;
    cache_file = cfg.spf.standardized_file;
else
    cache_file = char(input_arg);
    if nargin < 2 || isempty(cfg)
        cfg = default_config(); %#ok<NASGU>
    end
end

if exist(cache_file, 'file') ~= 2
    error('aggregate_spf_densities:MissingCache', ...
        'SPF density cache not found: %s', cache_file);
end

loaded = load(cache_file, 'spf');
if ~isfield(loaded, 'spf')
    error('aggregate_spf_densities:MissingVariable', ...
        'Cache file does not contain variable "spf": %s', cache_file);
end
spf = loaded.spf;

if ~isfield(spf, 'series') || isempty(spf.series)
    error('aggregate_spf_densities:NoSeries', ...
        'SPF cache contains no individual density series: %s', cache_file);
end

series = spf.series(:);
names = strings(numel(series), 1);
horizons = NaN(numel(series), 1);
for i = 1:numel(series)
    names(i) = map_spf_name(series(i).name);
    horizons(i) = series(i).horizon;
end

valid = strlength(names) > 0 & isfinite(horizons);
group_keys = names(valid) + "|" + string(horizons(valid));
[unique_keys, first_idx, group_idx] = unique(group_keys, 'stable');
valid_series_idx = find(valid);

agg_series = empty_aggregate_series();
warnings = {};

for g = 1:numel(unique_keys)
    member_idx = valid_series_idx(group_idx == g);
    if isempty(member_idx)
        continue;
    end

    out_name = char(names(member_idx(1)));
    out_horizon = horizons(member_idx(1));
    all_dates = collect_group_dates(series(member_idx));
    if isempty(all_dates)
        warnings{end + 1} = sprintf('%s h%s has no parseable dates.', ... %#ok<AGROW>
            out_name, num2str(out_horizon));
        continue;
    end

    n_dates = numel(all_dates);
    prob_by_date = cell(n_dates, 1);
    bin_edges_by_date = cell(n_dates, 1);
    n_total = zeros(n_dates, 1);
    n_used = zeros(n_dates, 1);
    mismatch_rate = NaN(n_dates, 1);

    for d = 1:n_dates
        [responses, bin_edges, response_warnings] = collect_date_responses( ...
            series(member_idx), all_dates(d), out_name, out_horizon);
        warnings = [warnings, response_warnings]; %#ok<AGROW>

        n_total(d) = numel(responses);
        if n_total(d) == 0
            prob_by_date{d} = [];
            bin_edges_by_date{d} = [];
            continue;
        end

        [modal_key, modal_edges] = modal_bin_set(bin_edges);
        keep = false(n_total(d), 1);
        for r = 1:n_total(d)
            keep(r) = strcmp(bin_key(bin_edges{r}), modal_key);
        end

        n_used(d) = sum(keep);
        mismatch_rate(d) = (n_total(d) - n_used(d)) ./ n_total(d);
        bin_edges_by_date{d} = modal_edges;
        prob_by_date{d} = consensus_prob(responses(keep));
    end

    usable = n_used > 0;
    if ~any(usable)
        warnings{end + 1} = sprintf('%s h%s has no usable consensus rows.', ... %#ok<AGROW>
            out_name, num2str(out_horizon));
        continue;
    end

    all_dates = all_dates(usable);
    prob_by_date = prob_by_date(usable);
    bin_edges_by_date = bin_edges_by_date(usable);
    n_total = n_total(usable);
    n_used = n_used(usable);
    mismatch_rate = mismatch_rate(usable);

    agg_series(end + 1) = struct( ... %#ok<AGROW>
        'name', out_name, ...
        'horizon', out_horizon, ...
        'dates', all_dates(:), ...
        'bin_edges_by_date', {bin_edges_by_date(:)}, ...
        'prob', {prob_by_date(:)}, ...
        'N_total', n_total(:), ...
        'N_used', n_used(:), ...
        'bins_mismatch_rate', mismatch_rate(:), ...
        'overall_bins_mismatch_rate', weighted_mismatch_rate(n_total, n_used), ...
        'source_series_count', numel(member_idx));
end

spf_agg = struct();
spf_agg.meta = struct();
spf_agg.meta.status = 'ok';
spf_agg.meta.source_file = cache_file;
spf_agg.meta.source_status = get_meta_status(spf);
spf_agg.meta.created_by = mfilename();
spf_agg.meta.name_map = struct('PRGDP', 'RGDP', 'PRPGDP', 'GDPD', 'PRUNEMP', 'UNR');
spf_agg.meta.series_count = numel(agg_series);
spf_agg.meta.warnings = warnings(:);
spf_agg.series = agg_series;

if isempty(agg_series)
    spf_agg.meta.status = 'no_series';
end
end

function out = empty_aggregate_series()
out = struct('name', {}, 'horizon', {}, 'dates', {}, ...
    'bin_edges_by_date', {}, 'prob', {}, 'N_total', {}, 'N_used', {}, ...
    'bins_mismatch_rate', {}, 'overall_bins_mismatch_rate', {}, ...
    'source_series_count', {});
end

function mapped = map_spf_name(name)
name = upper(strtrim(string(name)));
switch char(name)
    case 'PRGDP'
        mapped = "RGDP";
    case 'PRPGDP'
        mapped = "GDPD";
    case 'PRUNEMP'
        mapped = "UNR";
    otherwise
        mapped = name;
end
end

function dates = collect_group_dates(series)
dates = NaT(0, 1);
for i = 1:numel(series)
    if isfield(series(i), 'dates') && ~isempty(series(i).dates)
        dates = [dates; series(i).dates(:)]; %#ok<AGROW>
    end
end
dates = dates(~isnat(dates));
dates = unique(sort(dates), 'stable');
end

function [responses, bin_edges, warnings] = collect_date_responses(series, date_value, name, horizon)
responses = {};
bin_edges = {};
warnings = {};

for i = 1:numel(series)
    if isempty(series(i).dates) || isempty(series(i).prob)
        continue;
    end

    row = find(series(i).dates == date_value, 1, 'first');
    if isempty(row)
        continue;
    end

    prob = double(series(i).prob(row, :));
    if isempty(prob) || all(isnan(prob))
        continue;
    end

    row_sum = sum(prob, 2, 'omitnan');
    if ~isfinite(row_sum) || row_sum <= 0
        continue;
    end
    prob = prob ./ row_sum;

    edges = series(i).bin_edges;
    if isempty(edges)
        warnings{end + 1} = sprintf('%s h%s %s missing bin edges; response skipped.', ... %#ok<AGROW>
            name, num2str(horizon), datestr(date_value, 'yyyy-mm-dd'));
        continue;
    end

    if expected_bin_count(edges) ~= numel(prob)
        warnings{end + 1} = sprintf('%s h%s %s bin/prob size mismatch; response skipped.', ... %#ok<AGROW>
            name, num2str(horizon), datestr(date_value, 'yyyy-mm-dd'));
        continue;
    end

    responses{end + 1, 1} = prob; %#ok<AGROW>
    bin_edges{end + 1, 1} = edges; %#ok<AGROW>
end
end

function k = expected_bin_count(edges)
if isvector(edges)
    k = numel(edges(:)) - 1;
else
    k = size(edges, 1);
end
end

function [key, edges] = modal_bin_set(bin_edges)
keys = strings(numel(bin_edges), 1);
for i = 1:numel(bin_edges)
    keys(i) = string(bin_key(bin_edges{i}));
end

[unique_keys, ~, idx] = unique(keys, 'stable');
counts = accumarray(idx, 1);
[~, best] = max(counts);
key = char(unique_keys(best));
first = find(idx == best, 1, 'first');
edges = bin_edges{first};
end

function key = bin_key(edges)
sz = size(edges);
values = edges(:);
parts = strings(numel(values), 1);
for i = 1:numel(values)
    if isinf(values(i)) && values(i) < 0
        parts(i) = "-Inf";
    elseif isinf(values(i)) && values(i) > 0
        parts(i) = "Inf";
    elseif isnan(values(i))
        parts(i) = "NaN";
    else
        parts(i) = string(sprintf('%.12g', values(i)));
    end
end
key = sprintf('%dx%d:%s', sz(1), sz(2), strjoin(parts, ','));
end

function p = consensus_prob(responses)
if isempty(responses)
    p = [];
    return;
end

k = numel(responses{1});
mat = NaN(numel(responses), k);
for i = 1:numel(responses)
    mat(i, :) = responses{i};
end

denom = sum(~isnan(mat), 1);
num = sum_zero_nan(mat, 1);
p = num ./ denom;
p(denom == 0) = NaN;

row_sum = sum(p, 2, 'omitnan');
if isfinite(row_sum) && row_sum > 0
    p = p ./ row_sum;
end
end

function y = sum_zero_nan(x, dim)
x(isnan(x)) = 0;
y = sum(x, dim);
end

function rate = weighted_mismatch_rate(n_total, n_used)
denom = sum(n_total);
if denom <= 0
    rate = NaN;
else
    rate = sum(n_total - n_used) ./ denom;
end
end

function status = get_meta_status(spf)
if isfield(spf, 'meta') && isfield(spf.meta, 'status')
    status = spf.meta.status;
else
    status = '';
end
end
