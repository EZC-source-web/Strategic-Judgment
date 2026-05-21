function S15_aggregate_spf(cfg)
%S15_AGGREGATE_SPF Aggregate individual SPF densities into consensus series.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);

if ~isfield(cfg.spf, 'aggregate_file') || isempty(cfg.spf.aggregate_file)
    cfg.spf.aggregate_file = fullfile(cfg.cache, 'spf_aggregate.mat');
end

spf_agg = aggregate_spf_densities(cfg);
log_text = spf_aggregate_log_text(spf_agg);
write_text_file(fullfile(cfg.logs, 'spf_aggregate_log.txt'), log_text);

if strcmp(spf_agg.meta.status, 'ok')
    save_mat(cfg.spf.aggregate_file, 'spf_agg', spf_agg);
    pretty_print(sprintf('Saved SPF aggregate cache: %s', cfg.spf.aggregate_file), 'info');
else
    remove_stale_file(cfg.spf.aggregate_file);
    error('S15_aggregate_spf:NoAggregateSeries', ...
        'SPF aggregation produced no series. See %s.', ...
        fullfile(cfg.logs, 'spf_aggregate_log.txt'));
end

zip_file = create_spf_aggregate_bundle(cfg);
pretty_print(sprintf('Created SPF aggregate bundle: %s', zip_file), 'info');
mirror_spf_aggregate_bundle(zip_file, cfg);
end

function log_text = spf_aggregate_log_text(spf_agg)
lines = {};
lines{end + 1} = 'SPF aggregate log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', spf_agg.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('source_file: %s', spf_agg.meta.source_file); %#ok<AGROW>
lines{end + 1} = sprintf('aggregate_series_count: %d', numel(spf_agg.series)); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>

if isempty(spf_agg.series)
    lines{end + 1} = '  none'; %#ok<AGROW>
else
    for i = 1:numel(spf_agg.series)
        s = spf_agg.series(i);
        if isempty(s.dates)
            date_range = 'dates=n/a';
        else
            date_range = sprintf('dates=%s..%s', ...
                datestr(min(s.dates), 'yyyy-mm-dd'), datestr(max(s.dates), 'yyyy-mm-dd'));
        end
        lines{end + 1} = sprintf( ... %#ok<AGROW>
            '  %s h%s | %s | mean_N_used=%.2f | discarded_bins_mismatch=%.4f', ...
            s.name, num2str(s.horizon), date_range, ...
            mean(s.N_used), s.overall_bins_mismatch_rate);
    end
end

lines{end + 1} = '';
lines{end + 1} = 'Warnings:'; %#ok<AGROW>
if isempty(spf_agg.meta.warnings)
    lines{end + 1} = '  none'; %#ok<AGROW>
else
    warnings = spf_agg.meta.warnings;
    for i = 1:numel(warnings)
        lines{end + 1} = sprintf('  - %s', warnings{i}); %#ok<AGROW>
    end
end

log_text = strjoin(lines, newline);
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S15_aggregate_spf:LogOpenFailed', 'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_spf_aggregate_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['SPF_AGG_BUNDLE_', timestamp, '.zip']);

files = {
    fullfile('out', 'cache', 'spf_aggregate.mat')
    fullfile('out', 'logs', 'spf_aggregate_log.txt')
    fullfile('scripts', 'S15_aggregate_spf.m')
    fullfile('src', 'spf', 'aggregate_spf_densities.m')
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

function mirror_spf_aggregate_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied SPF aggregate bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy SPF aggregate bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function remove_stale_file(filename)
if exist(filename, 'file') == 2
    delete(filename);
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
