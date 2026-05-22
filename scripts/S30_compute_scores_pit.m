function report = S30_compute_scores_pit(cfg)
%S30_COMPUTE_SCORES_PIT Compute report PIT and log scores for aggregate SPF.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);

if ~isfield(cfg, 'report') || ~isfield(cfg.report, 'cache_file') || isempty(cfg.report.cache_file)
    cfg.report = struct();
    cfg.report.cache_file = fullfile(cfg.cache, 'report_scores_pit.mat');
end

if exist(cfg.spf.realized_file, 'file') ~= 2
    error('S30_compute_scores_pit:MissingRealizedCache', ...
        'SPF aggregate realized cache not found: %s', cfg.spf.realized_file);
end

loaded = load(cfg.spf.realized_file, 'spf_aggR');
if ~isfield(loaded, 'spf_aggR')
    error('S30_compute_scores_pit:MissingVariable', ...
        'Realized cache does not contain variable "spf_aggR": %s', cfg.spf.realized_file);
end

report = compute_report_scores(loaded.spf_aggR, cfg);
log_text = report_scores_log_text(report);

write_text_file(fullfile(cfg.logs, 'report_scores_pit_log.txt'), log_text);
save_mat(cfg.report.cache_file, 'report', report);
pretty_print(sprintf('Saved report PIT/logscore cache: %s', cfg.report.cache_file), 'info');

zip_file = create_report_bundle(cfg);
pretty_print(sprintf('Created SPF report bundle: %s', zip_file), 'info');
mirror_report_bundle(zip_file, cfg);
end

function report = compute_report_scores(spf_aggR, cfg)
series_out = empty_report_series();
global_counts = zero_counts();

for j = 1:numel(spf_aggR.series)
    s = spf_aggR.series(j);
    n_dates = numel(s.dates);
    pit = NaN(n_dates, 1);
    logscore = NaN(n_dates, 1);
    density_at_y = NaN(n_dates, 1);
    missing_flags = false(n_dates, 1);
    counts = zero_counts();
    counts.n_dates = n_dates;

    for t = 1:n_dates
        endpoints = get_bin_endpoints(s, t);
        prob_row = get_prob_row(s, t);
        y = get_realized_value(s, t);

        if isempty(endpoints) || isempty(prob_row) || ~isfinite(y)
            missing_flags(t) = true;
            counts.input_missing_count = counts.input_missing_count + 1;
            continue;
        end

        try
            [pit(t), pit_stats] = pit_from_hist(endpoints, prob_row, y);
            [logscore(t), density_at_y(t), log_stats] = logscore_from_hist(endpoints, prob_row, y);
            counts = add_stats(counts, pit_stats, log_stats);
        catch ME
            missing_flags(t) = true;
            counts.error_count = counts.error_count + 1;
            counts.error_messages{end + 1} = sprintf('%s %s t=%d: %s', ...
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

report = struct();
report.meta = struct();
report.meta.status = 'ok';
report.meta.created_by = mfilename();
report.meta.created_at = datestr(now, 'yyyy-mm-dd HH:MM:SS');
report.meta.source_file = cfg.spf.realized_file;
report.meta.series_count = numel(series_out);
report.meta.counts = global_counts;
report.series = series_out;
end

function out = empty_report_series()
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

function endpoints = get_bin_endpoints(s, idx)
endpoints = [];
if isfield(s, 'bin_edges_by_date') && numel(s.bin_edges_by_date) >= idx
    endpoints = s.bin_edges_by_date{idx};
elseif isfield(s, 'bin_edges') && ~isempty(s.bin_edges)
    endpoints = s.bin_edges;
end
end

function prob_row = get_prob_row(s, idx)
prob_row = [];
if isfield(s, 'prob_by_date') && numel(s.prob_by_date) >= idx
    prob_row = s.prob_by_date{idx};
elseif isfield(s, 'prob') && iscell(s.prob) && numel(s.prob) >= idx
    prob_row = s.prob{idx};
elseif isfield(s, 'prob') && isnumeric(s.prob) && size(s.prob, 1) >= idx
    prob_row = s.prob(idx, :);
end
if ~isempty(prob_row)
    prob_row = double(prob_row(:)');
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

function log_text = report_scores_log_text(report)
lines = {};
lines{end + 1} = 'SPF report PIT/logscore log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', report.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('source_file: %s', report.meta.source_file); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>

for i = 1:numel(report.series)
    s = report.series(i);
    c = s.stats;
    lines{end + 1} = sprintf(['  %s h%s | n_dates=%d | NaN_pit=%d | NaN_logscore=%d | ' ...
        'snapped_total=%d | still_missing_total=%d | sanitized_open_bins=%d | input_missing=%d | errors=%d'], ...
        s.name, num2str(s.horizon), c.n_dates, c.nan_pit_count, c.nan_logscore_count, ...
        c.snapped_total, c.still_missing_total, c.sanitized_open_bins_count, ...
        c.input_missing_count, c.error_count); %#ok<AGROW>
end

c = report.meta.counts;
lines{end + 1} = '';
lines{end + 1} = sprintf(['Global summary: n_dates=%d | NaN_pit=%d | NaN_logscore=%d | ' ...
    'snapped_total=%d | still_missing_total=%d | sanitized_open_bins=%d | input_missing=%d | errors=%d'], ...
    c.n_dates, c.nan_pit_count, c.nan_logscore_count, c.snapped_total, ...
    c.still_missing_total, c.sanitized_open_bins_count, c.input_missing_count, c.error_count); %#ok<AGROW>
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
    error('S30_compute_scores_pit:LogOpenFailed', 'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_report_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['SPF_REPORT_BUNDLE2_', timestamp, '.zip']);

files = {
    fullfile('out', 'cache', 'report_scores_pit.mat')
    fullfile('out', 'logs', 'report_scores_pit_log.txt')
    fullfile('scripts', 'S30_compute_scores_pit.m')
    fullfile('src', 'utils', 'pit_from_hist.m')
    fullfile('src', 'scoring_rules', 'logscore_from_hist.m')
    fullfile('tests', 'test_report_scores_pit.m')
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

function mirror_report_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied SPF report bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy SPF report bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
