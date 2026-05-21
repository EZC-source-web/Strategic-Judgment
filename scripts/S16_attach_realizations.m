function S16_attach_realizations(cfg)
%S16_ATTACH_REALIZATIONS Attach FRED outturns to aggregate SPF densities.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.bundles);
if ~isfield(cfg, 'fred') || ~isfield(cfg.fred, 'raw_dir') || isempty(cfg.fred.raw_dir)
    cfg.fred.raw_dir = fullfile(cfg.data_raw, 'fred');
end
ensure_dir(cfg.fred.raw_dir);

if ~isfield(cfg.spf, 'realized_file') || isempty(cfg.spf.realized_file)
    cfg.spf.realized_file = fullfile(cfg.cache, 'spf_aggregate_realized.mat');
end

spf_aggR = attach_realizations(cfg);
log_text = spf_realizations_log_text(spf_aggR);
readme_text = spf_realizations_readme_text(spf_aggR);

write_text_file(fullfile(cfg.logs, 'spf_realizations_log.txt'), log_text);
write_text_file(fullfile(cfg.logs, 'SPF_REALIZATIONS_README.txt'), readme_text);
save_mat(cfg.spf.realized_file, 'spf_aggR', spf_aggR);
pretty_print(sprintf('Saved SPF aggregate realizations cache: %s', cfg.spf.realized_file), 'info');

zip_file = create_spf_realized_bundle(cfg);
pretty_print(sprintf('Created SPF realized bundle: %s', zip_file), 'info');
mirror_spf_realized_bundle(zip_file, cfg);
end

function log_text = spf_realizations_log_text(spf_aggR)
lines = {};
lines{end + 1} = 'SPF realizations log'; %#ok<AGROW>
lines{end + 1} = sprintf('status: %s', spf_aggR.meta.realizations.status); %#ok<AGROW>
lines{end + 1} = sprintf('raw_dir: %s', spf_aggR.meta.realizations.raw_dir); %#ok<AGROW>
lines{end + 1} = sprintf('timing: %s', spf_aggR.meta.realizations.timing); %#ok<AGROW>
lines{end + 1} = '';
lines{end + 1} = 'FRED codes and transformations:'; %#ok<AGROW>

names = fieldnames(spf_aggR.meta.realizations.fred_codes);
for i = 1:numel(names)
    name = names{i};
    lines{end + 1} = sprintf('  %s: %s | %s', name, ...
        spf_aggR.meta.realizations.fred_codes.(name), ...
        spf_aggR.meta.realizations.transformations.(name)); %#ok<AGROW>
end

lines{end + 1} = '';
lines{end + 1} = 'Series:'; %#ok<AGROW>
total_nan = 0;
total_obs = 0;
for i = 1:numel(spf_aggR.series)
    s = spf_aggR.series(i);
    realized = s.realized_by_date(:);
    n_obs = numel(realized);
    n_nan = sum(isnan(realized));
    total_nan = total_nan + n_nan;
    total_obs = total_obs + n_obs;
    if isempty(s.dates)
        date_range = 'dates=n/a';
    else
        date_range = sprintf('issue_dates=%s..%s', ...
            datestr(min(s.dates), 'yyyy-mm-dd'), datestr(max(s.dates), 'yyyy-mm-dd'));
    end
    transform = spf_aggR.meta.realizations.transformations.(s.name);
    lines{end + 1} = sprintf(['  %s h%s | %s | missing_realized=%.2f%% ' ...
        '(%d/%d) | status=%s | transformation=%s'], ...
        s.name, num2str(s.horizon), date_range, ...
        100 .* n_nan ./ max(n_obs, 1), n_nan, n_obs, ...
        s.realized_status, transform); %#ok<AGROW>
end

lines{end + 1} = '';
lines{end + 1} = sprintf('Total NaN realized: %d/%d', total_nan, total_obs); %#ok<AGROW>
log_text = strjoin(lines, newline);
end

function readme_text = spf_realizations_readme_text(spf_aggR)
lines = {
    'SPF realizations attachment'
    ''
    'Timing convention: aggregate SPF dates are issue dates; target_date = issue_date + calquarters(horizon).'
    ''
    'FRED source codes and transformations:'
    };
names = fieldnames(spf_aggR.meta.realizations.fred_codes);
for i = 1:numel(names)
    name = names{i};
    lines{end + 1} = sprintf('- %s uses FRED %s: %s', name, ... %#ok<AGROW>
        spf_aggR.meta.realizations.fred_codes.(name), ...
        spf_aggR.meta.realizations.transformations.(name));
end
lines{end + 1} = '';
lines{end + 1} = 'Raw FRED CSV files are cached under data/raw/fred/ and are not versioned.';
readme_text = strjoin(lines, newline);
end

function write_text_file(filename, text)
ensure_dir(fileparts(filename));
fid = fopen(filename, 'w');
if fid < 0
    error('S16_attach_realizations:LogOpenFailed', 'Could not open log file: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
delete(cleanup);
end

function zip_file = create_spf_realized_bundle(cfg)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
zip_file = fullfile(cfg.bundles, ['SPF_REALIZED_BUNDLE_', timestamp, '.zip']);

files = {
    fullfile('out', 'cache', 'spf_aggregate_realized.mat')
    fullfile('out', 'logs', 'spf_realizations_log.txt')
    fullfile('out', 'logs', 'SPF_REALIZATIONS_README.txt')
    fullfile('scripts', 'S16_attach_realizations.m')
    fullfile('src', 'spf', 'attach_realizations.m')
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

function mirror_spf_realized_bundle(zip_file, cfg)
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
        pretty_print(sprintf('Copied SPF realized bundle to Dropbox review folder: %s', target_file), 'info');
    else
        pretty_print(sprintf('Could not copy SPF realized bundle to %s: %s', target_dir, msg), 'warn');
    end
end
end

function name = get_filename(pathname)
[~, base, ext] = fileparts(pathname);
name = [base, ext];
end
