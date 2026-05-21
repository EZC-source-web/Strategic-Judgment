function S17_bins_diagnostics(cfg)
%S17_BINS_DIAGNOSTICS Report histogram bin gaps and monotonicity issues.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);

diag = bins_diagnostics(cfg);
log_text = bins_diagnostics_log_text(diag);
write_text_file(fullfile(cfg.logs, 'bins_diagnostics_log.txt'), log_text);

zip_file = create_bins_bundle(cfg);
pretty_print(sprintf('Created SPF bins diagnostics bundle: %s', zip_file), 'info');
mirror_bins_bundle(zip_file, cfg);
end

function log_text = bins_diagnostics_log_text(diag)
lines = {};
lines{end + 1} = 'SPF bins diagnostics log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', diag.meta.status); %#ok<AGROW>
lines{end + 1} = sprintf('source_file: %s', diag.meta.source_file); %#ok<AGROW>
lines{end + 1} = sprintf('gap_tolerance: %.12g', diag.meta.gap_tolerance); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>

for i = 1:numel(diag.series)
    s = diag.series(i);
    if isempty(s.dates)
        date_range = 'dates=n/a';
    else
        date_range = sprintf('dates=%s..%s', ...
            datestr(min(s.dates), 'yyyy-mm-dd'), datestr(max(s.dates), 'yyyy-mm-dd'));
    end
    lines{end + 1} = sprintf(['  %s h%s | %s | median_gap=%.12g | max_gap=%.12g | ' ...
        'dates_gap_gt_tol=%d | nonmonotone_dates=%d | ' ...
        'realized_in_gap_raw=%d | realized_in_gap_snapped=%d'], ...
        s.name, num2str(s.horizon), date_range, s.median_gap, s.max_gap, ...
        s.dates_with_gap_count, s.nonmonotone_count, ...
        s.realized_in_gap_raw_count, s.realized_in_gap_snapped_count); %#ok<AGROW>
    if s.realized_in_gap_raw_count > 0
        lines{end + 1} = sprintf('    realized_in_gap_raw_dates: %s', ...
            join_dates(s.realized_in_gap_raw_dates)); %#ok<AGROW>
    end
    if s.realized_in_gap_snapped_count > 0
        lines{end + 1} = sprintf('    realized_in_gap_snapped_dates: %s', ...
            join_dates(s.realized_in_gap_snapped_dates)); %#ok<AGROW>
    end
end

log_text = strjoin(lines, newline);
end

function text = join_dates(dates)
parts = cell(numel(dates), 1);
for i = 1:numel(dates)
    parts{i} = datestr(dates(i), 'yyyy-mm-dd');
end
text = strjoin(parts, ', ');
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S17_bins_diagnostics:LogOpenFailed', 'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_bins_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['SPF_BINS_BUNDLE2_', timestamp, '.zip']);

files = {
    fullfile('out', 'logs', 'bins_diagnostics_log.txt')
    fullfile('src', 'utils', 'snap_realized_to_bin_grid.m')
    fullfile('src', 'utils', 'sanitize_hist_bins.m')
    fullfile('src', 'utils', 'pit_from_hist.m')
    fullfile('src', 'scoring_rules', 'logscore_from_hist.m')
    fullfile('scripts', 'S17_bins_diagnostics.m')
    fullfile('src', 'spf', 'bins_diagnostics.m')
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

function mirror_bins_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied SPF bins diagnostics bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy SPF bins diagnostics bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
