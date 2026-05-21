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
save_mat(cfg.spf.standardized_file, 'spf', spf);
write_text_file(fullfile(cfg.logs, 'spf_summary.txt'), summary_text);
write_text_file(fullfile(cfg.logs, 'spf_parser_log.txt'), spf_parser_log_text(spf));

pretty_print(sprintf('Saved SPF cache: %s', cfg.spf.standardized_file), 'info');
zip_file = create_spf_bundle(cfg);
pretty_print(sprintf('Created SPF parser bundle: %s', zip_file), 'info');
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
    fullfile('out', 'cache', 'spf_densities.mat')
    fullfile('out', 'logs', 'spf_summary.txt')
    fullfile('out', 'logs', 'spf_parser_log.txt')
    fullfile('src', 'spf', 'parse_spf_densities.m')
    fullfile('scripts', 'S10_parse_spf.m')
    fullfile('src', 'utils', 'pit_from_hist.m')
    fullfile('tests', 'test_spf_parser.m')
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
