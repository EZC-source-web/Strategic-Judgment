function wedge = S32_compute_wedge(cfg)
%S32_COMPUTE_WEDGE Compute Report-Benchmark logscore wedges.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);

if ~isfield(cfg.benchmarks, 'scores_file') || isempty(cfg.benchmarks.scores_file)
    cfg.benchmarks.scores_file = fullfile(cfg.cache, 'benchmark_scores_pit.mat');
end
if ~isfield(cfg, 'wedge') || ~isfield(cfg.wedge, 'cache_file') || isempty(cfg.wedge.cache_file)
    cfg.wedge = struct();
    cfg.wedge.cache_file = fullfile(cfg.cache, 'wedge_scores_pit.mat');
end

report_loaded = load_required(cfg.report.cache_file, 'report');
bench_loaded = load_required(cfg.benchmarks.scores_file, 'bench_scores');

wedge = compute_wedge(report_loaded.report, bench_loaded.bench_scores, cfg);
log_text = wedge_log_text(wedge);
write_text_file(fullfile(cfg.logs, 'wedge_log.txt'), log_text);
save_mat(cfg.wedge.cache_file, 'wedge', wedge);
pretty_print(sprintf('Saved report-benchmark wedge cache: %s', cfg.wedge.cache_file), 'info');

zip_file = create_wedge_bundle(cfg);
pretty_print(sprintf('Created WEDGE bundle: %s', zip_file), 'info');
mirror_wedge_bundle(zip_file, cfg);
end

function loaded = load_required(filename, varname)
if exist(filename, 'file') ~= 2
    error('S32_compute_wedge:MissingInput', 'Required cache not found: %s', filename);
end
loaded = load(filename, varname);
if ~isfield(loaded, varname)
    error('S32_compute_wedge:MissingVariable', ...
        'Cache %s does not contain variable "%s".', filename, varname);
end
end

function wedge = compute_wedge(report, bench_scores, cfg)
series_out = empty_wedge_series();
global_values = [];
global_nan = 0;
global_n = 0;

for j = 1:numel(report.series)
    r = report.series(j);
    b_idx = find_matching_series(bench_scores.series, r.name, r.horizon);
    if isempty(b_idx)
        continue;
    end
    b = bench_scores.series(b_idx);

    [dates, r_pos, b_pos] = intersect(r.dates(:), b.dates(:));
    report_logscore = r.logscore(r_pos);
    bench_logscore = b.logscore(b_pos);
    report_pit = r.pit(r_pos);
    bench_pit = b.pit(b_pos);
    wedge_logscore = report_logscore - bench_logscore;

    finite = isfinite(wedge_logscore);
    global_values = [global_values; wedge_logscore(finite)]; %#ok<AGROW>
    global_nan = global_nan + sum(~finite);
    global_n = global_n + numel(wedge_logscore);

    series_out(end + 1) = struct( ... %#ok<AGROW>
        'name', r.name, ...
        'horizon', r.horizon, ...
        'dates', dates(:), ...
        'report_logscore', report_logscore(:), ...
        'bench_logscore', bench_logscore(:), ...
        'wedge_logscore', wedge_logscore(:), ...
        'report_pit', report_pit(:), ...
        'bench_pit', bench_pit(:), ...
        'stats', series_stats(wedge_logscore));
end

wedge = struct();
wedge.meta = struct();
wedge.meta.status = 'ok';
wedge.meta.created_by = mfilename();
wedge.meta.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
wedge.meta.report_file = cfg.report.cache_file;
wedge.meta.benchmark_scores_file = cfg.benchmarks.scores_file;
wedge.meta.series_count = numel(series_out);
wedge.meta.global = struct('n', global_n, 'nan_count', global_nan, ...
    'mean', mean_or_nan(global_values), 'sd', std_or_nan(global_values));
wedge.series = series_out;
end

function out = empty_wedge_series()
out = struct('name', {}, 'horizon', {}, 'dates', {}, ...
    'report_logscore', {}, 'bench_logscore', {}, 'wedge_logscore', {}, ...
    'report_pit', {}, 'bench_pit', {}, 'stats', {});
end

function idx = find_matching_series(series, name, horizon)
idx = [];
for i = 1:numel(series)
    if strcmp(series(i).name, name) && isequal(series(i).horizon, horizon)
        idx = i;
        return;
    end
end
end

function stats = series_stats(x)
finite = x(isfinite(x));
stats = struct();
stats.n = numel(x);
stats.nan_count = sum(~isfinite(x));
stats.mean = mean_or_nan(finite);
stats.sd = std_or_nan(finite);
end

function y = mean_or_nan(x)
if isempty(x)
    y = NaN;
else
    y = mean(x);
end
end

function y = std_or_nan(x)
if numel(x) < 2
    y = NaN;
else
    y = std(x);
end
end

function log_text = wedge_log_text(wedge)
lines = {};
lines{end + 1} = 'Report-Benchmark wedge log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', wedge.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('report_file: %s', wedge.meta.report_file); %#ok<AGROW>
lines{end + 1} = sprintf('benchmark_scores_file: %s', wedge.meta.benchmark_scores_file); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>

for i = 1:numel(wedge.series)
    s = wedge.series(i);
    st = s.stats;
    lines{end + 1} = sprintf('  %s h%s | n=%d | NaN=%d | mean=%0.6f | sd=%0.6f', ...
        s.name, num2str(s.horizon), st.n, st.nan_count, st.mean, st.sd); %#ok<AGROW>
end

g = wedge.meta.global;
lines{end + 1} = '';
lines{end + 1} = sprintf('Global summary: series=%d | n=%d | NaN=%d | mean=%0.6f | sd=%0.6f', ...
    wedge.meta.series_count, g.n, g.nan_count, g.mean, g.sd); %#ok<AGROW>
log_text = strjoin(lines, newline);
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S32_compute_wedge:LogOpenFailed', ...
        'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_wedge_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['WEDGE_BUNDLE_', timestamp, '.zip']);

files = {
    fullfile('out', 'cache', 'benchmark_scores_pit.mat')
    fullfile('out', 'cache', 'wedge_scores_pit.mat')
    fullfile('out', 'logs', 'benchmark_scores_pit_log.txt')
    fullfile('out', 'logs', 'wedge_log.txt')
    fullfile('scripts', 'S31_compute_benchmark_scores.m')
    fullfile('scripts', 'S32_compute_wedge.m')
    fullfile('scripts', 'S20_build_benchmark.m')
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

function mirror_wedge_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied WEDGE bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy WEDGE bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
