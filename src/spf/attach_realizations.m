function spf_aggR = attach_realizations(input_arg, cfg)
%ATTACH_REALIZATIONS Add realized outcomes to aggregate SPF density series.
%
% Timing convention:
%   series(j).dates are issue dates, i.e. SPF survey quarters.
%   series(j).horizon is the lead in quarters.
%   target_date = issue_date + calquarters(horizon).
%
% Realizations:
%   RGDP  -> FRED GDPC1, annualized quarterly log growth
%   GDPD  -> FRED GDPDEF, annualized quarterly log growth
%   UNR   -> FRED UNRATE, quarterly average level in percent

if nargin < 1 || isempty(input_arg)
    cfg = default_config();
    aggregate_file = cfg.spf.aggregate_file;
elseif isstruct(input_arg)
    cfg = input_arg;
    aggregate_file = cfg.spf.aggregate_file;
else
    aggregate_file = char(input_arg);
    if nargin < 2 || isempty(cfg)
        cfg = default_config();
    end
end

if ~isfield(cfg, 'fred') || ~isfield(cfg.fred, 'raw_dir') || isempty(cfg.fred.raw_dir)
    cfg.fred.raw_dir = fullfile(cfg.data_raw, 'fred');
end

if exist(aggregate_file, 'file') ~= 2
    error('attach_realizations:MissingAggregate', ...
        'SPF aggregate cache not found: %s', aggregate_file);
end

loaded = load(aggregate_file, 'spf_agg');
if ~isfield(loaded, 'spf_agg')
    error('attach_realizations:MissingVariable', ...
        'Aggregate cache does not contain variable "spf_agg": %s', aggregate_file);
end
spf_agg = loaded.spf_agg;

fred = load_fred_realizations(cfg.fred.raw_dir);

spf_aggR = spf_agg;
spf_aggR.meta.realizations = struct();
spf_aggR.meta.realizations.status = 'ok';
spf_aggR.meta.realizations.created_by = mfilename();
spf_aggR.meta.realizations.raw_dir = cfg.fred.raw_dir;
spf_aggR.meta.realizations.timing = ['series.dates are issue dates; ' ...
    'target_date = issue_date + calquarters(horizon).'];
spf_aggR.meta.realizations.fred_codes = fred.codes;
spf_aggR.meta.realizations.transformations = fred.transformations;
spf_aggR.meta.realizations.total_nan = 0;

if ~isfield(spf_aggR, 'series') || isempty(spf_aggR.series)
    spf_aggR.meta.realizations.status = 'no_series';
    return;
end

for j = 1:numel(spf_aggR.series)
    s = spf_aggR.series(j);
    [realized, status, missing_count] = attach_one_series(s, fred);
    spf_aggR.series(j).realized_by_date = realized(:);
    spf_aggR.series(j).realized_status = status;
    spf_aggR.series(j).target_dates = target_dates(s.dates, s.horizon);
    spf_aggR.meta.realizations.total_nan = spf_aggR.meta.realizations.total_nan + missing_count;
end
end

function [realized, status, missing_count] = attach_one_series(s, fred)
name = upper(strtrim(s.name));
targets = target_dates(s.dates, s.horizon);
realized = NaN(numel(targets), 1);

if ~isfield(fred.series, name)
    status = 'missing_fred_mapping';
    missing_count = numel(targets);
    return;
end

actual = fred.series.(name);
for i = 1:numel(targets)
    if isnat(targets(i))
        continue;
    end
    idx = find(actual.dates == targets(i), 1, 'first');
    if ~isempty(idx)
        realized(i) = actual.values(idx);
    end
end

missing_count = sum(isnan(realized));
if missing_count == 0
    status = 'ok';
elseif missing_count == numel(realized)
    status = 'all_missing';
else
    status = 'partial_missing';
end
end

function targets = target_dates(issue_dates, horizon)
targets = issue_dates(:);
if isempty(targets)
    return;
end
try
    targets = targets + calquarters(horizon);
catch
    targets = addtodate(targets, horizon * 3, 'month');
end
targets = dateshift(targets, 'start', 'quarter');
end

function fred = load_fred_realizations(raw_dir)
ensure_dir(raw_dir);

specs = struct( ...
    'name', {'RGDP', 'GDPD', 'UNR'}, ...
    'code', {'GDPC1', 'GDPDEF', 'UNRATE'}, ...
    'frequency', {'quarterly', 'quarterly', 'monthly'}, ...
    'transformation', { ...
        '400*log(GDPC1_t/GDPC1_{t-1}); annualized quarterly log percent change', ...
        '400*log(GDPDEF_t/GDPDEF_{t-1}); annualized quarterly log percent change', ...
        'Quarterly average of monthly UNRATE; level in percent'});

fred = struct();
fred.raw_dir = raw_dir;
fred.codes = struct();
fred.transformations = struct();
fred.series = struct();

for i = 1:numel(specs)
    spec = specs(i);
    fred.codes.(spec.name) = spec.code;
    fred.transformations.(spec.name) = spec.transformation;
    csv_file = ensure_fred_csv(raw_dir, spec.code);
    tbl = read_fred_csv(csv_file, spec.code);

    switch spec.name
        case {'RGDP', 'GDPD'}
            actual = quarterly_log_growth(tbl);
        case 'UNR'
            actual = quarterly_average(tbl);
        otherwise
            actual = struct('dates', NaT(0, 1), 'values', NaN(0, 1));
    end
    actual.code = spec.code;
    actual.frequency = spec.frequency;
    actual.transformation = spec.transformation;
    actual.raw_file = csv_file;
    fred.series.(spec.name) = actual;
end
end

function csv_file = ensure_fred_csv(raw_dir, code)
csv_file = fullfile(raw_dir, [code, '.csv']);
if exist(csv_file, 'file') == 2
    return;
end

url = ['https://fred.stlouisfed.org/graph/fredgraph.csv?id=', code];
try
    opts = weboptions('Timeout', 60);
    websave(csv_file, url, opts);
catch ME
    error('attach_realizations:FredDownloadFailed', ...
        'Could not download FRED series %s from %s: %s', code, url, ME.message);
end
end

function tbl = read_fred_csv(csv_file, code)
opts = detectImportOptions(csv_file, 'FileType', 'text');
tbl_in = readtable(csv_file, opts);
if width(tbl_in) < 2
    error('attach_realizations:FredReadFailed', ...
        'FRED file has fewer than two columns: %s', csv_file);
end

vars = tbl_in.Properties.VariableNames;
date_col = vars{1};
value_col = '';
for i = 1:numel(vars)
    if strcmpi(vars{i}, code)
        value_col = vars{i};
        break;
    end
end
if isempty(value_col)
    value_col = vars{2};
end

dates = parse_fred_dates(tbl_in.(date_col));
values = parse_fred_values(tbl_in.(value_col));
tbl = table(dates(:), values(:), 'VariableNames', {'date', 'value'});
tbl = tbl(~isnat(tbl.date) & isfinite(tbl.value), :);
end

function dates = parse_fred_dates(col)
if isdatetime(col)
    dates = col(:);
else
    dates = datetime(string(col), 'InputFormat', 'yyyy-MM-dd');
end
dates = dateshift(dates, 'start', 'day');
end

function values = parse_fred_values(col)
if isnumeric(col)
    values = double(col(:));
else
    txt = string(col);
    txt(txt == ".") = missing;
    values = str2double(txt);
end
end

function actual = quarterly_log_growth(tbl)
[dates, order] = sort(tbl.date);
levels = tbl.value(order);
values = NaN(size(levels));
valid = isfinite(levels) & levels > 0;
values(2:end) = 400 .* log(levels(2:end) ./ levels(1:(end - 1)));
values(~valid) = NaN;
values([false; ~valid(1:(end - 1))]) = NaN;
actual = struct('dates', dates(:), 'values', values(:));
end

function actual = quarterly_average(tbl)
qdates = dateshift(tbl.date, 'start', 'quarter');
[unique_dates, ~, idx] = unique(qdates, 'stable');
values = NaN(numel(unique_dates), 1);
for i = 1:numel(unique_dates)
    vals = tbl.value(idx == i);
    vals = vals(isfinite(vals));
    if ~isempty(vals)
        values(i) = mean(vals);
    end
end
actual = struct('dates', unique_dates(:), 'values', values(:));
end
