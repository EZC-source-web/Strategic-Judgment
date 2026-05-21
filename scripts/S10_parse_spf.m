function S10_parse_spf(cfg)
%S10_PARSE_SPF Parse SPF density forecasts into a standardized cache file.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);

spf = parse_spf_densities(cfg.spf.raw_dir, cfg);
summary_text = spf_summary_text(spf);
print_spf_summary(summary_text, spf);
write_text_file(fullfile(cfg.logs, 'spf_summary.txt'), summary_text);
write_text_file(fullfile(cfg.logs, 'spf_parser_log.txt'), spf_parser_log_text(spf));

if strcmp(spf.meta.status, 'ok')
    save_mat(cfg.spf.standardized_file, 'spf', spf);
    pretty_print(sprintf('Saved SPF cache: %s', cfg.spf.standardized_file), 'info');
else
    remove_stale_cache(cfg.spf.standardized_file);
    write_needed_from_user(cfg, spf);
end

zip_file = create_spf_bundle(cfg);
pretty_print(sprintf('Created SPF parser bundle: %s', zip_file), 'info');
mirror_spf_bundle(zip_file, cfg);

if any(strcmp(spf.meta.status, {'missing_raw_dir', 'no_files', 'no_series', 'weak_bins'}))
    error('S10_parse_spf:ParserNotReady', ...
        ['SPF parser status is %s. See %s and %s. Cache was not saved. ' ...
        'Bundle: %s'], spf.meta.status, fullfile(cfg.logs, 'spf_summary.txt'), ...
        fullfile(cfg.logs, 'spf_parser_log.txt'), zip_file);
end
end

function print_spf_summary(summary_text, spf)
if isempty(spf.series)
    pretty_print(summary_text, 'warn');
else
    pretty_print(summary_text, 'info');
end
end

function summary_text = spf_summary_text(spf)
series = spf.series;
if isempty(series)
    summary_text = sprintf('SPF summary: status=%s, series=0', spf.meta.status);
    return;
end

horizons = unique([series.horizon]);
k = arrayfun(@(s) size(s.prob, 2), series);

all_dates = vertcat(series.dates);
all_dates = all_dates(~isnat(all_dates));
if isempty(all_dates)
    date_msg = 'dates=n/a';
else
    date_msg = sprintf('dates=%s..%s', datestr(min(all_dates), 'yyyy-mm-dd'), ...
        datestr(max(all_dates), 'yyyy-mm-dd'));
end

summary_text = sprintf('SPF summary: status=%s, series=%d, horizons=%s, %s, typical K=%g', ...
    spf.meta.status, numel(series), mat2str(horizons), date_msg, median(k));
end

function log_text = spf_parser_log_text(spf)
lines = {};
lines{end + 1} = 'SPF parser log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', spf.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('raw_dir: %s', spf.meta.raw_dir); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Parsed files/sheets:'; %#ok<AGROW>

if isempty(spf.meta.files)
    lines{end + 1} = '  none'; %#ok<AGROW>
else
    files = spf.meta.files;
    for i = 1:numel(files)
        sheet = files(i).sheet;
        if isempty(sheet)
            sheet = '(n/a)';
        end
        lines{end + 1} = sprintf('  %s | sheet=%s | format=%s | series=%d | status=%s | %s', ...
            files(i).path, sheet, files(i).format, files(i).series_count, ...
            files(i).status, files(i).message); %#ok<AGROW>
    end
end

lines{end + 1} = '';
lines{end + 1} = 'Series diagnostics:'; %#ok<AGROW>
series = spf.series;
if isempty(series)
    lines{end + 1} = '  none'; %#ok<AGROW>
    lines{end + 1} = '  series_count: 0'; %#ok<AGROW>
    lines{end + 1} = '  horizons: []'; %#ok<AGROW>
    lines{end + 1} = '  typical_K: NaN'; %#ok<AGROW>
else
    horizons = unique([series.horizon]);
    k = arrayfun(@(s) size(s.prob, 2), series);
    missing_realized = arrayfun(@(s) all(isnan(s.realized)), series);
    lines{end + 1} = sprintf('  series_count: %d', numel(series)); %#ok<AGROW>
    lines{end + 1} = sprintf('  horizons: %s', mat2str(horizons)); %#ok<AGROW>
    lines{end + 1} = sprintf('  typical_K: %g', median(k)); %#ok<AGROW>
    lines{end + 1} = sprintf('  realized_all_missing_series: %d', sum(missing_realized)); %#ok<AGROW>
    if any(missing_realized)
        lines{end + 1} = '  note: some realized values are missing and are stored as NaN.'; %#ok<AGROW>
    end
end

lines{end + 1} = '';
lines{end + 1} = 'Warnings:'; %#ok<AGROW>
if isempty(spf.meta.warnings)
    lines{end + 1} = '  none'; %#ok<AGROW>
else
    warnings = spf.meta.warnings;
    for i = 1:numel(warnings)
        lines{end + 1} = sprintf('  - %s', warnings{i}); %#ok<AGROW>
    end
end

if ~isempty(spf.meta.todo)
    lines{end + 1} = '';
    lines{end + 1} = sprintf('TODO: %s', spf.meta.todo); %#ok<AGROW>
end

log_text = strjoin(lines, newline);
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S10_parse_spf:LogOpenFailed', 'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_spf_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['SPF_PARSER_BUNDLE_', timestamp, '.zip']);

files = {
    fullfile('out', 'logs', 'spf_summary.txt')
    fullfile('out', 'logs', 'spf_parser_log.txt')
    fullfile('out', 'logs', 'NEEDED_FROM_USER.txt')
    fullfile('config', 'default_config.m')
    fullfile('src', 'spf', 'parse_spf_densities.m')
    fullfile('scripts', 'S10_parse_spf.m')
    fullfile('src', 'utils', 'pit_from_hist.m')
    fullfile('tests', 'test_spf_parser.m')
    };
if exist(cfg.spf.standardized_file, 'file') == 2
    files = [{fullfile('out', 'cache', 'spf_densities.mat')}; files];
end

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

function mirror_spf_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied SPF parser bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy SPF parser bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end

function remove_stale_cache(filename)
if exist(filename, 'file') == 2
    delete(filename);
end
end

function write_needed_from_user(cfg, spf)
filename = fullfile(cfg.logs, 'NEEDED_FROM_USER.txt');
lines = {
    'SPF raw data are needed before the parser can create a standardized cache.'
    ''
    sprintf('Current parser status: %s', spf.meta.status)
    sprintf('Expected raw directory: %s', fullfile(cfg.data_raw, 'spf'))
    ''
    'Please place SPF density forecast raw files under data/raw/spf/.'
    'Supported file types: .csv, .txt, .dat, .xls, .xlsx, .mat.'
    'Useful file/path keywords: spf, density, histogram, prob, bins, RGDP, GDPD, UNR.'
    ''
    'Alternatively set the environment variable SJ_SPF_RAW_DIR to a folder containing those files.'
    'Example from a shell before launching MATLAB:'
    '  export SJ_SPF_RAW_DIR=/path/to/spf/raw/files'
    ''
    'No empty spf_densities.mat cache was saved.'
    };
write_text_file(filename, strjoin(lines, newline));
end
