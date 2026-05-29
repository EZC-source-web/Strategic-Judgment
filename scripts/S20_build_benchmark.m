function bench = S20_build_benchmark(cfg)
%S20_BUILD_BENCHMARK Build benchmark quotation densities by bootstrap.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);
ensure_dir(cfg.fred.raw_dir);

if exist(cfg.spf.realized_file, 'file') ~= 2
    error('S20_build_benchmark:MissingInput', ...
        'Missing SPF aggregate realized cache: %s', cfg.spf.realized_file);
end

ensure_fred_files(cfg);
fred = load_fred_quarterly(cfg);

loaded = load(cfg.spf.realized_file, 'spf_aggR');
if ~isfield(loaded, 'spf_aggR')
    error('S20_build_benchmark:MissingVariable', ...
        'Input file does not contain spf_aggR: %s', cfg.spf.realized_file);
end

rng(cfg.benchmarks.seed, 'twister');
[bench, log_text] = build_benchmark_struct(loaded.spf_aggR, fred, cfg);
write_text_file(fullfile(cfg.logs, 'benchmark_log.txt'), log_text);
save_mat(cfg.benchmarks.cache_file, 'bench', bench);
pretty_print(sprintf('Saved benchmark forecasts: %s', cfg.benchmarks.cache_file), 'info');

zip_file = create_benchmark_bundle(cfg);
pretty_print(sprintf('Created benchmark bundle: %s', zip_file), 'info');
mirror_benchmark_bundle(zip_file, cfg);
end

function ensure_fred_files(cfg)
series = {'INDPRO', 'GDPC1', 'GDPDEF', 'UNRATE'};
for i = 1:numel(series)
    code = series{i};
    filename = fullfile(cfg.fred.raw_dir, [code, '.csv']);
    if exist(filename, 'file') == 2 && dir(filename).bytes > 0
        continue;
    end
    url = ['https://fred.stlouisfed.org/graph/fredgraph.csv?id=', code];
    try
        websave(filename, url);
    catch ME
        error('S20_build_benchmark:FredDownloadFailed', ...
            'Could not download %s from FRED: %s', code, ME.message);
    end
end

for i = 1:numel(series)
    filename = fullfile(cfg.fred.raw_dir, [series{i}, '.csv']);
    if exist(filename, 'file') ~= 2 || dir(filename).bytes <= 0
        error('S20_build_benchmark:InvalidFredFile', ...
            'Missing or empty FRED CSV: %s', filename);
    end
    opts = detectImportOptions(filename);
    if numel(opts.VariableNames) < 2
        error('S20_build_benchmark:InvalidFredFile', ...
            'FRED CSV does not look valid: %s', filename);
    end
end
end

function fred = load_fred_quarterly(cfg)
[gdpc1_dates, gdpc1] = read_fred_csv(fullfile(cfg.fred.raw_dir, 'GDPC1.csv'));
[gdpdef_dates, gdpdef] = read_fred_csv(fullfile(cfg.fred.raw_dir, 'GDPDEF.csv'));
[unrate_m_dates, unrate_m] = read_fred_csv(fullfile(cfg.fred.raw_dir, 'UNRATE.csv'));
[indpro_m_dates, indpro_m] = read_fred_csv(fullfile(cfg.fred.raw_dir, 'INDPRO.csv'));

[unr_dates, unr_level] = monthly_to_quarterly_mean(unrate_m_dates, unrate_m);
[indpro_q_dates, indpro_level] = monthly_to_quarterly_mean(indpro_m_dates, indpro_m);

fred = struct();
[fred.RGDP.dates, fred.RGDP.y] = log_growth(gdpc1_dates, gdpc1);
[fred.GDPD.dates, fred.GDPD.y] = log_growth(gdpdef_dates, gdpdef);
fred.UNR.dates = unr_dates(:);
fred.UNR.y = unr_level(:);
[fred.INDPRO_GROWTH.dates, fred.INDPRO_GROWTH.y] = log_growth(indpro_q_dates, indpro_level);
end

function [dates, values] = read_fred_csv(filename)
opts = detectImportOptions(filename);
opts = setvartype(opts, opts.VariableNames{1}, 'datetime');
opts = setvaropts(opts, opts.VariableNames{1}, 'InputFormat', 'yyyy-MM-dd');
tbl = readtable(filename, opts);
dates = tbl{:, 1};
raw_values = tbl{:, 2};
if iscell(raw_values) || isstring(raw_values)
    values = str2double(string(raw_values));
else
    values = double(raw_values);
end
ok = ~isnat(dates) & isfinite(values);
dates = dates(ok);
values = values(ok);
dates = dateshift(dates, 'start', 'quarter');
end

function [q_dates, q_values] = monthly_to_quarterly_mean(dates, values)
q_all = dateshift(dates(:), 'start', 'quarter');
q_dates = unique(q_all);
q_values = NaN(numel(q_dates), 1);
for i = 1:numel(q_dates)
    idx = q_all == q_dates(i) & isfinite(values(:));
    if any(idx)
        q_values(i) = mean(values(idx));
    end
end
ok = isfinite(q_values);
q_dates = q_dates(ok);
q_values = q_values(ok);
end

function [growth_dates, growth] = log_growth(dates, levels)
dates = dates(:);
levels = levels(:);
ok = isfinite(levels) & levels > 0;
dates = dates(ok);
levels = levels(ok);
growth_dates = dates(2:end);
growth = 400 * diff(log(levels));
end

function [bench, log_text] = build_benchmark_struct(spf_aggR, fred, cfg)
series_out = empty_benchmark_series();
log_lines = {};
log_lines{end + 1} = 'SPF benchmark quotation log'; %#ok<AGROW>
log_lines{end + 1} = sprintf('created_at: %s', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<AGROW>
log_lines{end + 1} = sprintf('B: %d', cfg.benchmarks.B); %#ok<AGROW>
log_lines{end + 1} = sprintf('AR lag order: %d', cfg.benchmarks.p); %#ok<AGROW>
log_lines{end + 1} = 'FRED transformations: RGDP=400*diff(log(GDPC1)); GDPD=400*diff(log(GDPDEF)); UNR=quarterly mean UNRATE; INDPRO_growth=400*diff(log(quarterly mean INDPRO)).'; %#ok<AGROW>
log_lines{end + 1} = '';

global_missing = 0;
global_dates = 0;

for j = 1:numel(spf_aggR.series)
    s = spf_aggR.series(j);
    [model_y_dates, model_y, x_dates, x_values, spec] = select_model_data(s.name, fred);
    n_dates = numel(s.dates);
    prob_by_date = cell(n_dates, 1);
    warnings = {};
    missing_count = 0;
    renorm_count = 0;
    sample_start = NaT;
    sample_end = NaT;

    for t = 1:n_dates
        issue_date = dateshift(s.dates(t), 'start', 'quarter');
        target_date = issue_date + calquarters(s.horizon);
        train_end = issue_date - calquarters(1);
        h_steps = quarter_distance(train_end, target_date);
        endpoints = get_bin_endpoints(s, t);

        if isempty(endpoints) || h_steps < 1
            missing_count = missing_count + 1;
            prob_by_date{t} = NaN(1, size(endpoints, 1));
            continue;
        end

        train_idx = model_y_dates <= train_end;
        y_train = model_y(train_idx);
        train_dates = model_y_dates(train_idx);
        x_train = [];
        if strcmp(spec, 'ARX2_INDPRO')
            x_train = align_x_to_dates(train_dates, x_dates, x_values);
        end

        if numel(y_train(isfinite(y_train))) < cfg.benchmarks.min_obs
            missing_count = missing_count + 1;
            prob_by_date{t} = NaN(1, size(endpoints, 1));
            continue;
        end

        try
            model = fit_arx(y_train, cfg.benchmarks.p, x_train, true);
            draws = simulate_arx_bootstrap(model, y_train, h_steps, cfg.benchmarks.B, []);
            [prob, was_renorm] = map_draws_to_bins(draws, endpoints);
            prob_by_date{t} = prob;
            renorm_count = renorm_count + double(was_renorm);
            if isnat(sample_start) || train_dates(1) < sample_start
                sample_start = train_dates(1);
            end
            if isnat(sample_end) || train_dates(end) > sample_end
                sample_end = train_dates(end);
            end
        catch ME
            missing_count = missing_count + 1;
            prob_by_date{t} = NaN(1, size(endpoints, 1));
            warnings{end + 1} = sprintf('%s h%s %s: %s', ...
                s.name, num2str(s.horizon), datestr(issue_date, 'yyyy-qq'), ME.message); %#ok<AGROW>
        end
    end

    series_out(end + 1) = struct( ... %#ok<AGROW>
        'name', s.name, ...
        'horizon', s.horizon, ...
        'model_spec', spec, ...
        'dates', s.dates(:), ...
        'bin_edges_by_date', {s.bin_edges_by_date(:)}, ...
        'prob_by_date', {prob_by_date(:)}, ...
        'realized_by_date', s.realized_by_date(:), ...
        'target_dates', get_target_dates(s), ...
        'B', cfg.benchmarks.B, ...
        'missing_count', missing_count, ...
        'renormalized_count', renorm_count);

    global_missing = global_missing + missing_count;
    global_dates = global_dates + n_dates;
    log_lines{end + 1} = sprintf(['%s h%s | model=%s | n_dates=%d | B=%d | ' ...
        'sample_start=%s | sample_end=%s | missing=%d | renormalized=%d | warnings=%d'], ...
        s.name, num2str(s.horizon), spec, n_dates, cfg.benchmarks.B, ...
        safe_datestr(sample_start), safe_datestr(sample_end), missing_count, ...
        renorm_count, numel(warnings)); %#ok<AGROW>
    for w = 1:min(numel(warnings), 10)
        log_lines{end + 1} = ['  warning: ', warnings{w}]; %#ok<AGROW>
    end
end

log_lines{end + 1} = '';
log_lines{end + 1} = sprintf('Global summary: series=%d | n_dates=%d | missing=%d', ...
    numel(series_out), global_dates, global_missing); %#ok<AGROW>

bench = struct();
bench.meta = struct();
bench.meta.status = 'ok';
bench.meta.created_by = mfilename();
bench.meta.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
bench.meta.source_file = cfg.spf.realized_file;
bench.meta.B = cfg.benchmarks.B;
bench.meta.model_spec = 'AR2 for GDPD/UNR; ARX2_INDPRO for RGDP';
bench.meta.fred_codes = {'INDPRO', 'GDPC1', 'GDPDEF', 'UNRATE'};
bench.meta.counts = struct('series', numel(series_out), ...
    'n_dates', global_dates, 'missing', global_missing);
bench.series = series_out;
log_text = strjoin(log_lines, newline);
end

function out = empty_benchmark_series()
out = struct('name', {}, 'horizon', {}, 'model_spec', {}, 'dates', {}, ...
    'bin_edges_by_date', {}, 'prob_by_date', {}, 'realized_by_date', {}, ...
    'target_dates', {}, 'B', {}, 'missing_count', {}, 'renormalized_count', {});
end

function [dates, y, x_dates, x, spec] = select_model_data(name, fred)
x_dates = [];
x = [];
switch upper(char(name))
    case 'RGDP'
        dates = fred.RGDP.dates;
        y = fred.RGDP.y;
        x_dates = fred.INDPRO_GROWTH.dates;
        x = fred.INDPRO_GROWTH.y;
        spec = 'ARX2_INDPRO';
    case 'GDPD'
        dates = fred.GDPD.dates;
        y = fred.GDPD.y;
        spec = 'AR2';
    case 'UNR'
        dates = fred.UNR.dates;
        y = fred.UNR.y;
        spec = 'AR2';
    otherwise
        error('S20_build_benchmark:UnknownSeries', ...
            'No benchmark model configured for SPF series "%s".', name);
end
dates = dates(:);
y = y(:);
end

function x_aligned = align_x_to_dates(y_dates, x_dates, x_values)
x_aligned = NaN(numel(y_dates), 1);
for i = 1:numel(y_dates)
    idx = find(x_dates == y_dates(i), 1, 'first');
    if ~isempty(idx)
        x_aligned(i) = x_values(idx);
    end
end
end

function endpoints = get_bin_endpoints(s, idx)
endpoints = [];
if isfield(s, 'bin_edges_by_date') && numel(s.bin_edges_by_date) >= idx
    endpoints = s.bin_edges_by_date{idx};
elseif isfield(s, 'bin_edges') && ~isempty(s.bin_edges)
    endpoints = s.bin_edges;
end
end

function target_dates = get_target_dates(s)
if isfield(s, 'target_dates') && numel(s.target_dates) == numel(s.dates)
    target_dates = s.target_dates(:);
else
    target_dates = s.dates(:) + calquarters(s.horizon);
end
end

function h = quarter_distance(train_end, target_date)
h = 4 * (year(target_date) - year(train_end)) + ...
    (quarter(target_date) - quarter(train_end));
end

function [prob, was_renorm] = map_draws_to_bins(draws, endpoints)
draws = draws(isfinite(draws));
K = size(endpoints, 1);
prob = NaN(1, K);
was_renorm = false;
if isempty(draws) || K == 0
    return;
end

lower = endpoints(:, 1);
upper = endpoints(:, 2);
prob = zeros(1, K);
for k = 1:K
    if k == K
        in_bin = draws >= lower(k) & draws <= upper(k);
    else
        in_bin = draws >= lower(k) & draws < upper(k);
    end
    prob(k) = mean(in_bin);
end

total = sum(prob);
if total > 0 && abs(total - 1) > 1e-6
    prob = prob ./ total;
    was_renorm = true;
end
end

function out = safe_datestr(d)
if isempty(d) || isnat(d)
    out = 'NA';
else
    out = datestr(d, 'yyyy-mm-dd');
end
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S20_build_benchmark:LogOpenFailed', ...
        'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_benchmark_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['BENCHMARK_BUNDLE_', timestamp, '.zip']);

files = {
    fullfile('out', 'cache', 'benchmark_forecasts.mat')
    fullfile('out', 'logs', 'benchmark_log.txt')
    fullfile('scripts', 'S20_build_benchmark.m')
    fullfile('src', 'benchmarks', 'fit_arx.m')
    fullfile('src', 'benchmarks', 'simulate_arx_bootstrap.m')
    };

existing = {};
for i = 1:numel(files)
    if exist(fullfile(cfg.root, files{i}), 'file') == 2
        existing{end + 1} = files{i}; %#ok<AGROW>
    end
end

original_dir = pwd;
cleanup = onCleanup(@() cd(original_dir));
cd(cfg.root);
zip(zip_file, existing);
delete(cleanup);
end

function mirror_benchmark_bundle(zip_file, cfg)
if ~isfield(cfg, 'bundle_mirror_dirs') || isempty(cfg.bundle_mirror_dirs)
    return;
end

for i = 1:numel(cfg.bundle_mirror_dirs)
    target_dir = cfg.bundle_mirror_dirs{i};
    if exist(target_dir, 'dir') ~= 7
        continue;
    end
    target_file = fullfile(target_dir, get_filename(zip_file));
    [ok, msg] = copyfile(zip_file, target_file, 'f');
    if ok
        pretty_print(sprintf('Copied benchmark bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy benchmark bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
