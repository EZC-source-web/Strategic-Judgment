function bench_scores = S31_compute_benchmark_scores(cfg)
%S31_COMPUTE_BENCHMARK_SCORES Compute PIT/logscore for benchmark densities.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);

if ~isfield(cfg.benchmarks, 'scores_file') || isempty(cfg.benchmarks.scores_file)
    cfg.benchmarks.scores_file = fullfile(cfg.cache, 'benchmark_scores_pit.mat');
end

if exist(cfg.benchmarks.cache_file, 'file') ~= 2
    error('S31_compute_benchmark_scores:MissingInput', ...
        'Benchmark forecast cache not found: %s', cfg.benchmarks.cache_file);
end

loaded = load(cfg.benchmarks.cache_file, 'bench');
if ~isfield(loaded, 'bench')
    error('S31_compute_benchmark_scores:MissingVariable', ...
        'Benchmark cache does not contain variable "bench": %s', cfg.benchmarks.cache_file);
end

bench_scores = compute_benchmark_scores(loaded.bench, cfg);
log_text = benchmark_scores_log_text(bench_scores);
write_text_file(fullfile(cfg.logs, 'benchmark_scores_pit_log.txt'), log_text);
save_mat(cfg.benchmarks.scores_file, 'bench_scores', bench_scores);
pretty_print(sprintf('Saved benchmark PIT/logscore cache: %s', ...
    cfg.benchmarks.scores_file), 'info');
end

function bench_scores = compute_benchmark_scores(bench, cfg)
series_out = empty_scores_series();
global_counts = zero_counts();

for j = 1:numel(bench.series)
    s = bench.series(j);
    n_dates = numel(s.dates);
    pit = NaN(n_dates, 1);
    logscore = NaN(n_dates, 1);
    density_at_y = NaN(n_dates, 1);
    missing_flags = false(n_dates, 1);
    counts = zero_counts();
    counts.n_dates = n_dates;

    for t = 1:n_dates
        endpoints = get_cell_or_empty(s.bin_edges_by_date, t);
        prob_row = get_cell_or_empty(s.prob_by_date, t);
        y = get_realized_value(s, t);

        if isempty(endpoints) || isempty(prob_row) || any(~isfinite(prob_row)) || ~isfinite(y)
            missing_flags(t) = true;
            counts.input_missing_count = counts.input_missing_count + 1;
            continue;
        end

        try
            [pit(t), pit_stats] = pit_from_hist(endpoints, double(prob_row(:)'), y);
            [logscore(t), density_at_y(t), log_stats] = ...
                logscore_from_hist(endpoints, double(prob_row(:)'), y);
            counts = add_stats(counts, pit_stats, log_stats);
        catch ME
            missing_flags(t) = true;
            counts.error_count = counts.error_count + 1;
            counts.error_messages{end + 1} = sprintf('%s h%s t=%d: %s', ...
                s.name, num2str(s.horizon), t, ME.message); %#ok<AGROW>
        end
    end

    counts.nan_pit_count = sum(isnan(pit));
    counts.nan_logscore_count = sum(isnan(logscore));
    global_counts = add_counts(global_counts, counts);

    series_out(end + 1) = struct( ... %#ok<AGROW>
        'name', s.name, ...
        'horizon', s.horizon, ...
        'dates', s.dates(:), ...
        'pit', pit(:), ...
        'logscore', logscore(:), ...
        'density_at_y', density_at_y(:), ...
        'missing_flags', missing_flags(:), ...
        'stats', counts);
end

bench_scores = struct();
bench_scores.meta = struct();
bench_scores.meta.status = 'ok';
bench_scores.meta.created_by = mfilename();
bench_scores.meta.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
bench_scores.meta.source_file = cfg.benchmarks.cache_file;
bench_scores.meta.series_count = numel(series_out);
bench_scores.meta.counts = global_counts();
bench_scores.series = series_out;
end

function out = empty_scores_series()
out = struct('name', {}, 'horizon', {}, 'dates', {}, 'pit', {}, ...
    'logscore', {}, 'density_at_y', {}, 'missing_flags', {}, 'stats', {});
end

function counts = zero_counts()
counts = struct();
counts.n_dates = 0;
counts.input_missing_count = 0;
counts.nan_pit_count = 0;
counts.nan_logscore_count = 0;
counts.snapped_total = 0;
counts.still_missing_total = 0;
counts.sanitized_open_bins_count = 0;
counts.error_count = 0;
counts.error_messages = {};
end

function counts = add_stats(counts, pit_stats, log_stats)
counts.snapped_total = counts.snapped_total + pit_stats.snapped_count;
counts.still_missing_total = counts.still_missing_total + max( ...
    pit_stats.still_missing_count, log_stats.still_missing_count);
if pit_stats.sanitized_open_bins || log_stats.sanitized_open_bins
    counts.sanitized_open_bins_count = counts.sanitized_open_bins_count + 1;
end
end

function out = add_counts(out, counts)
out.n_dates = out.n_dates + counts.n_dates;
out.input_missing_count = out.input_missing_count + counts.input_missing_count;
out.nan_pit_count = out.nan_pit_count + counts.nan_pit_count;
out.nan_logscore_count = out.nan_logscore_count + counts.nan_logscore_count;
out.snapped_total = out.snapped_total + counts.snapped_total;
out.still_missing_total = out.still_missing_total + counts.still_missing_total;
out.sanitized_open_bins_count = out.sanitized_open_bins_count + counts.sanitized_open_bins_count;
out.error_count = out.error_count + counts.error_count;
out.error_messages = [out.error_messages(:); counts.error_messages(:)];
end

function value = get_cell_or_empty(cell_array, idx)
value = [];
if iscell(cell_array) && numel(cell_array) >= idx
    value = cell_array{idx};
end
end

function y = get_realized_value(s, idx)
y = NaN;
if ~isfield(s, 'realized_by_date') || numel(s.realized_by_date) < idx
    return;
end
if iscell(s.realized_by_date)
    y_val = s.realized_by_date{idx};
else
    y_val = s.realized_by_date(idx);
end
if ~isempty(y_val)
    y = double(y_val(1));
end
end

function log_text = benchmark_scores_log_text(bench_scores)
lines = {};
lines{end + 1} = 'Benchmark PIT/logscore log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', bench_scores.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('source_file: %s', bench_scores.meta.source_file); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>

for i = 1:numel(bench_scores.series)
    s = bench_scores.series(i);
    c = s.stats;
    lines{end + 1} = sprintf(['  %s h%s | n_dates=%d | NaN_pit=%d | ' ...
        'NaN_logscore=%d | input_missing=%d | snapped_total=%d | ' ...
        'still_missing_total=%d | errors=%d'], ...
        s.name, num2str(s.horizon), c.n_dates, c.nan_pit_count, ...
        c.nan_logscore_count, c.input_missing_count, c.snapped_total, ...
        c.still_missing_total, c.error_count); %#ok<AGROW>
end

c = bench_scores.meta.counts;
lines{end + 1} = '';
lines{end + 1} = sprintf(['Global summary: n_dates=%d | NaN_pit=%d | ' ...
    'NaN_logscore=%d | input_missing=%d | snapped_total=%d | ' ...
    'still_missing_total=%d | errors=%d'], ...
    c.n_dates, c.nan_pit_count, c.nan_logscore_count, c.input_missing_count, ...
    c.snapped_total, c.still_missing_total, c.error_count); %#ok<AGROW>
if ~isempty(c.error_messages)
    lines{end + 1} = '';
    lines{end + 1} = 'Errors:'; %#ok<AGROW>
    for i = 1:numel(c.error_messages)
        lines{end + 1} = ['  ', c.error_messages{i}]; %#ok<AGROW>
    end
end

log_text = strjoin(lines, newline);
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S31_compute_benchmark_scores:LogOpenFailed', ...
        'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end
