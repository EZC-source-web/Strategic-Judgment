function spf = parse_spf_densities(raw_dir, cfg)
%PARSE_SPF_DENSITIES Parse SPF density forecast files.
%
% spf = PARSE_SPF_DENSITIES(raw_dir, cfg) recursively scans raw_dir for
% tabular raw files and converts histogram-style density forecasts into a
% stable internal schema. Supported file types are CSV, TXT, DAT, XLS, XLSX,
% and MAT files containing tables or structs convertible to tables.
%
% Output schema:
%   spf.meta.status       'ok' when at least one series is parsed.
%   spf.meta.raw_dir      Raw SPF directory.
%   spf.meta.files        Parsed files and sheets.
%   spf.series(i).name
%   spf.series(i).horizon
%   spf.series(i).dates
%   spf.series(i).bin_edges
%   spf.series(i).prob
%   spf.series(i).realized
%   spf.series(i).forecaster_id
%   spf.series(i).vintage

if nargin < 2
    cfg = default_config(); %#ok<NASGU>
end

spf = empty_spf(raw_dir);

if exist(raw_dir, 'dir') ~= 7
    spf.meta.status = 'missing_raw_dir';
    spf.meta.todo = sprintf('Create %s and place SPF density files there.', raw_dir);
    pretty_print(sprintf('SPF raw directory not found: %s', raw_dir), 'warn');
    return;
end

raw_files = list_raw_files(raw_dir);
if isempty(raw_files)
    spf.meta.status = 'no_files';
    spf.meta.todo = sprintf('Place SPF density files under %s.', raw_dir);
    pretty_print(sprintf('No SPF raw files found under %s', raw_dir), 'warn');
    return;
end

warnings = {};
parsed_files = struct('path', {}, 'format', {}, 'sheet', {}, ...
    'series_count', {}, 'status', {}, 'message', {});
series = empty_series();

for i = 1:numel(raw_files)
    file = raw_files{i};
    [~, ~, ext] = fileparts(file);
    ext = lower(ext);

    try
        tables = read_raw_tables(file, ext);
        for j = 1:numel(tables)
            tbl = tables(j).table;
            if isempty(tbl) || height(tbl) == 0
                parsed_files(end + 1) = struct( ... %#ok<AGROW>
                    'path', file, 'format', ext, 'sheet', tables(j).sheet, ...
                    'series_count', 0, 'status', 'empty', 'message', 'empty table');
                continue;
            end

            [new_series, new_warnings] = parse_table_series(tbl, file, tables(j).sheet);
            warnings = [warnings, new_warnings]; %#ok<AGROW>
            sheet_status = 'ok';
            sheet_message = '';
            if ~isempty(new_series)
                series = append_series(series, new_series);
            else
                sheet_status = 'skip';
                sheet_message = 'no density series detected';
            end
            parsed_files(end + 1) = struct( ... %#ok<AGROW>
                'path', file, 'format', ext, 'sheet', tables(j).sheet, ...
                'series_count', numel(new_series), 'status', sheet_status, ...
                'message', sheet_message);
        end
    catch ME
        warnings{end + 1} = sprintf('%s: %s', file, ME.message); %#ok<AGROW>
        parsed_files(end + 1) = struct( ... %#ok<AGROW>
            'path', file, 'format', ext, 'sheet', '', ...
            'series_count', 0, 'status', 'error', 'message', ME.message);
    end
end

spf.meta.files = parsed_files;
spf.meta.warnings = warnings(:);
spf.series = series;

if isempty(series)
    spf.meta.status = 'no_series';
    spf.meta.todo = ['Raw files were found, but no density table matched the ' ...
        'parser heuristics. Check variable names for date, probability, and bin columns.'];
else
    if any(contains(string(spf.meta.warnings), 'WEAK_BINS'))
        spf.meta.status = 'weak_bins';
        spf.meta.todo = ['At least one parsed series used ordinal fallback bin ' ...
            'edges. Provide raw files with numeric bin endpoints or probability column names.'];
    else
        spf.meta.status = 'ok';
    end
    if any(arrayfun(@(s) all(isnan(s.realized)), series))
        realized_todo = ['Some series do not include realized values; supply ' ...
            'realizations later before scoring/PIT steps.'];
        if isempty(spf.meta.todo)
            spf.meta.todo = realized_todo;
        else
            spf.meta.todo = [spf.meta.todo, ' ', realized_todo];
        end
    end
end
end

function spf = empty_spf(raw_dir)
spf = struct();
spf.meta = struct();
spf.meta.status = 'init';
spf.meta.raw_dir = raw_dir;
spf.meta.files = struct('path', {}, 'format', {}, 'sheet', {}, ...
    'series_count', {}, 'status', {}, 'message', {});
spf.meta.warnings = {};
spf.meta.todo = '';
spf.series = empty_series();
end

function s = empty_series()
s = struct('name', {}, 'horizon', {}, 'dates', {}, 'bin_edges', {}, ...
    'prob', {}, 'realized', {}, 'forecaster_id', {}, 'vintage', {}, ...
    'source_file', {}, 'source_sheet', {});
end

function out = append_series(out, add)
if isempty(out)
    out = add;
else
    out = [out(:); add(:)];
end
end

function files = list_raw_files(raw_dir)
all_files = dir(fullfile(raw_dir, '**', '*'));
all_files = all_files(~[all_files.isdir]);
files = {};
allowed = {'.csv', '.txt', '.dat', '.xls', '.xlsx', '.mat'};

for i = 1:numel(all_files)
    [~, name, ext] = fileparts(all_files(i).name);
    if startsWith(name, '.') || startsWith(name, '~$')
        continue;
    end
    if any(strcmpi(ext, allowed))
        files{end + 1} = fullfile(all_files(i).folder, all_files(i).name); %#ok<AGROW>
    end
end
files = sort(files);
end

function tables = read_raw_tables(file, ext)
tables = struct('sheet', {}, 'table', {});

switch ext
    case {'.csv', '.txt', '.dat'}
        opts = detectImportOptions(file, 'FileType', 'text');
        tbl = readtable(file, opts);
        tables(1) = struct('sheet', '', 'table', tbl);

    case {'.xls', '.xlsx'}
        sheets = sheetnames_compat(file);
        for i = 1:numel(sheets)
            try
                opts = detectImportOptions(file, 'Sheet', sheets{i});
                tbl = readtable(file, opts);
                tables(end + 1) = struct('sheet', sheets{i}, 'table', tbl); %#ok<AGROW>
            catch
                % Some workbook sheets are notes/charts. Skip unreadable sheets.
            end
        end

    case '.mat'
        data = load(file);
        names = fieldnames(data);
        for i = 1:numel(names)
            tbl = value_to_table(data.(names{i}));
            if ~isempty(tbl)
                tables(end + 1) = struct('sheet', names{i}, 'table', tbl); %#ok<AGROW>
            end
        end
end
end

function sheets = sheetnames_compat(file)
try
    sheets = sheetnames(file);
catch
    [~, sheets] = xlsfinfo(file);
end
if ischar(sheets)
    sheets = {sheets};
end
end

function tbl = value_to_table(x)
tbl = table();
if istable(x)
    tbl = x;
elseif isstruct(x)
    try
        tbl = struct2table(x);
    catch
        tbl = table();
    end
elseif isnumeric(x) && ismatrix(x)
    tbl = array2table(x);
end
end

function [series, warnings] = parse_table_series(tbl, file, sheet)
warnings = {};
series = empty_series();

tbl = normalize_table(tbl);
vars = tbl.Properties.VariableNames;
roles = detect_roles(vars);

[philly_series, philly_warnings, handled] = parse_philly_probability_series(tbl, file, sheet);
if handled
    series = philly_series;
    warnings = [warnings, philly_warnings];
    return;
end

if isempty(roles.date) || isempty(roles.prob)
    return;
end

dates_all = parse_dates(tbl.(roles.date));
if all(isnat(dates_all))
    warnings{end + 1} = sprintf('%s:%s has no parseable date column.', file, sheet);
    return;
end

if is_long_format(roles)
    [series, warnings] = parse_long_table_series(tbl, file, sheet, roles, dates_all);
    return;
end

group_cols = {};
for c = {'name', 'horizon', 'forecaster_id', 'vintage'}
    role_name = c{1};
    if ~isempty(roles.(role_name))
        group_cols{end + 1} = roles.(role_name); %#ok<AGROW>
    end
end

groups = table_groups(tbl, group_cols);
for g = 1:numel(groups)
    idx = groups(g).idx;
    sub = tbl(idx, :);
    dates = dates_all(idx);
    [dates, order] = sort(dates);
    sub = sub(order, :);

    prob = table_to_matrix(sub, roles.prob);
    [bin_edges, bin_order, bin_warnings] = detect_bin_edges(roles.prob);
    warnings = [warnings, bin_warnings]; %#ok<AGROW>
    if isempty(bin_edges)
        continue;
    end
    prob = prob(:, bin_order);

    realized = NaN(height(sub), 1);
    if ~isempty(roles.realized)
        realized = numeric_column(sub.(roles.realized));
    end

    if ~isempty(roles.name)
        name = first_string(sub.(roles.name));
    else
        name = infer_name_from_file(file);
    end
    if isempty(name)
        name = 'UNKNOWN';
    end

    if ~isempty(roles.horizon)
        horizon = first_numeric(sub.(roles.horizon));
    else
        horizon = infer_horizon_from_text(file);
    end

    [prob, normalize_warnings] = validate_prob(prob, file, sheet, name, horizon);
    warnings = [warnings, normalize_warnings]; %#ok<AGROW>

    [ok_bins, bin_msg] = validate_bins(bin_edges);
    if ~ok_bins
        warnings{end + 1} = sprintf('%s:%s invalid bins for %s h%s: %s', ...
            file, sheet, name, num2str(horizon), bin_msg);
        continue;
    end

    [dates, unique_idx] = unique(dates, 'stable');
    sub_prob = prob(unique_idx, :);
    sub_realized = realized(unique_idx);
    if ~issorted(dates)
        [dates, order2] = sort(dates);
        sub_prob = sub_prob(order2, :);
        sub_realized = sub_realized(order2);
    end

    if ~issorted(dates)
        warnings{end + 1} = sprintf('%s:%s dates could not be sorted for %s.', ...
            file, sheet, name);
        continue;
    end

    forecaster_id = '';
    if ~isempty(roles.forecaster_id)
        forecaster_id = first_string(sub.(roles.forecaster_id));
    end
    vintage = NaT(size(dates));
    if ~isempty(roles.vintage)
        vintage = parse_dates(sub.(roles.vintage));
        vintage = vintage(unique_idx);
    end

    series(end + 1) = struct( ... %#ok<AGROW>
        'name', char(name), ...
        'horizon', horizon, ...
        'dates', dates(:), ...
        'bin_edges', bin_edges, ...
        'prob', sub_prob, ...
        'realized', sub_realized(:), ...
        'forecaster_id', char(forecaster_id), ...
        'vintage', vintage(:), ...
        'source_file', file, ...
        'source_sheet', sheet);
end
end

function tf = is_long_format(roles)
tf = numel(roles.prob) == 1 && ~isempty(roles.bin_lower) && ~isempty(roles.bin_upper);
end

function [series, warnings] = parse_long_table_series(tbl, file, sheet, roles, dates_all)
warnings = {};
series = empty_series();

lower_all = numeric_column(tbl.(roles.bin_lower));
upper_all = numeric_column(tbl.(roles.bin_upper));
prob_all = numeric_column(tbl.(roles.prob{1}));

valid_bins = isfinite(lower_all) & isfinite(upper_all) & lower_all < upper_all;
if ~any(valid_bins)
    warnings{end + 1} = sprintf('%s:%s long format detected, but bin endpoints could not be inferred.', ...
        file, sheet);
    return;
end
if any(~valid_bins)
    warnings{end + 1} = sprintf('%s:%s dropped %d long-format rows with invalid bin endpoints.', ...
        file, sheet, sum(~valid_bins));
end

tbl = tbl(valid_bins, :);
dates_all = dates_all(valid_bins);
lower_all = lower_all(valid_bins);
upper_all = upper_all(valid_bins);
prob_all = prob_all(valid_bins);

group_cols = {};
for c = {'name', 'horizon', 'forecaster_id'}
    role_name = c{1};
    if ~isempty(roles.(role_name))
        group_cols{end + 1} = roles.(role_name); %#ok<AGROW>
    end
end

groups = table_groups(tbl, group_cols);
for g = 1:numel(groups)
    idx = groups(g).idx;
    sub = tbl(idx, :);
    dates = dates_all(idx);
    lower = lower_all(idx);
    upper = upper_all(idx);
    prob_long = prob_all(idx);

    [bin_edges, bin_key, bin_warnings] = long_bin_edges(lower, upper, file, sheet);
    warnings = [warnings, bin_warnings]; %#ok<AGROW>
    if isempty(bin_edges)
        continue;
    end

    if ~isempty(roles.vintage)
        vintage_all = parse_dates(sub.(roles.vintage));
    else
        vintage_all = NaT(height(sub), 1);
    end

    forecast_keys = strings(height(sub), 1);
    for i = 1:height(sub)
        forecast_keys(i) = datetime_key(dates(i)) + "|" + datetime_key(vintage_all(i));
    end
    [unique_keys, first_idx, forecast_idx] = unique(forecast_keys, 'stable'); %#ok<ASGLU>

    n_forecasts = numel(first_idx);
    k_bins = size(bin_key, 1);
    prob = NaN(n_forecasts, k_bins);
    realized = NaN(n_forecasts, 1);
    out_dates = dates(first_idx);
    out_vintage = vintage_all(first_idx);

    if ~isempty(roles.realized)
        realized_all = numeric_column(sub.(roles.realized));
    else
        realized_all = NaN(height(sub), 1);
    end

    for i = 1:height(sub)
        row = forecast_idx(i);
        bin = find(abs(bin_key(:, 1) - lower(i)) < 1e-12 & ...
            abs(bin_key(:, 2) - upper(i)) < 1e-12, 1, 'first');
        if isempty(bin)
            warnings{end + 1} = sprintf('%s:%s long-format row could not be assigned to a bin.', ...
                file, sheet); %#ok<AGROW>
            continue;
        end
        if isnan(prob(row, bin))
            prob(row, bin) = prob_long(i);
        else
            prob(row, bin) = prob(row, bin) + prob_long(i);
            warnings{end + 1} = sprintf('%s:%s duplicate long-format bin rows were summed.', ...
                file, sheet); %#ok<AGROW>
        end
        if isnan(realized(row)) && isfinite(realized_all(i))
            realized(row) = realized_all(i);
        end
    end
    prob(isnan(prob)) = 0;

    if ~isempty(roles.name)
        name = first_string(sub.(roles.name));
    else
        name = infer_name_from_file(file);
    end
    if isempty(name)
        name = 'UNKNOWN';
    end

    if ~isempty(roles.horizon)
        horizon = first_numeric(sub.(roles.horizon));
    else
        horizon = infer_horizon_from_text(file);
    end

    [prob, normalize_warnings] = validate_prob(prob, file, sheet, name, horizon);
    warnings = [warnings, normalize_warnings]; %#ok<AGROW>

    [ok_bins, bin_msg] = validate_bins(bin_edges);
    if ~ok_bins
        warnings{end + 1} = sprintf('%s:%s invalid long-format bins for %s h%s: %s', ...
            file, sheet, name, num2str(horizon), bin_msg);
        continue;
    end

    [out_dates, order] = sort(out_dates);
    prob = prob(order, :);
    realized = realized(order);
    out_vintage = out_vintage(order);

    [out_dates, unique_idx] = unique(out_dates, 'stable');
    if numel(unique_idx) < numel(order)
        warnings{end + 1} = sprintf('%s:%s duplicate forecast dates collapsed for %s h%s.', ...
            file, sheet, name, num2str(horizon));
    end
    prob = prob(unique_idx, :);
    realized = realized(unique_idx);
    out_vintage = out_vintage(unique_idx);

    if ~issorted(out_dates)
        warnings{end + 1} = sprintf('%s:%s dates could not be sorted for %s.', ...
            file, sheet, name);
        continue;
    end

    forecaster_id = '';
    if ~isempty(roles.forecaster_id)
        forecaster_id = first_string(sub.(roles.forecaster_id));
    end

    series(end + 1) = struct( ... %#ok<AGROW>
        'name', char(name), ...
        'horizon', horizon, ...
        'dates', out_dates(:), ...
        'bin_edges', bin_edges, ...
        'prob', prob, ...
        'realized', realized(:), ...
        'forecaster_id', char(forecaster_id), ...
        'vintage', out_vintage(:), ...
        'source_file', file, ...
        'source_sheet', sheet);
end
end

function [series, warnings, handled] = parse_philly_probability_series(tbl, file, sheet)
%PARSE_PHILLY_PROBABILITY_SERIES Handle Philadelphia Fed Individual_PR*.xlsx files.

warnings = {};
series = empty_series();
handled = false;

vars = tbl.Properties.VariableNames;
lower_vars = lower(vars);
year_col = first_exact_match(vars, lower_vars, 'year');
quarter_col = first_exact_match(vars, lower_vars, 'quarter');
id_col = first_exact_match(vars, lower_vars, 'id');
if isempty(year_col) || isempty(quarter_col)
    return;
end

roots = {'PRGDP', 'PRPGDP', 'PRUNEMP'};
root_cols = struct();
has_root = false;
for r = 1:numel(roots)
    root = roots{r};
    [cols, nums] = philly_probability_columns(vars, root);
    root_cols.(root).cols = cols;
    root_cols.(root).nums = nums;
    has_root = has_root || ~isempty(cols);
end
if ~has_root
    return;
end
handled = true;

years = numeric_column(tbl.(year_col));
quarters = numeric_column(tbl.(quarter_col));
valid_dates = isfinite(years) & isfinite(quarters) & quarters >= 1 & quarters <= 4;
if ~any(valid_dates)
    warnings{end + 1} = sprintf('%s:%s has YEAR/QUARTER columns, but no valid survey dates.', file, sheet);
    return;
end

dates_all = NaT(size(years));
dates_all(valid_dates) = datetime(years(valid_dates), (quarters(valid_dates) - 1) * 3 + 1, 1);

if isempty(id_col)
    id_keys = strings(height(tbl), 1);
else
    id_keys = string(tbl.(id_col));
end

for r = 1:numel(roots)
    root = roots{r};
    cols = root_cols.(root).cols;
    nums = root_cols.(root).nums;
    if isempty(cols)
        continue;
    end

    prob_all = table_to_matrix(tbl, cols);
    regimes = philly_probability_regimes(root);
    for rg = 1:numel(regimes)
        regime = regimes(rg);
        row_mask = valid_dates & dates_all >= regime.start_date & dates_all <= regime.end_date;
        if ~any(row_mask)
            continue;
        end

        ids = unique(id_keys(row_mask), 'stable');
        for id_idx = 1:numel(ids)
            id_mask = row_mask & id_keys == ids(id_idx);
            for horizon = 0:(regime.n_horizons - 1)
                doc_nums = horizon .* regime.k_bins + (1:regime.k_bins);
                col_idx = NaN(1, regime.k_bins);
                for k = 1:regime.k_bins
                    hit = find(nums == doc_nums(k), 1, 'first');
                    if ~isempty(hit)
                        col_idx(k) = hit;
                    end
                end
                if any(isnan(col_idx))
                    warnings{end + 1} = sprintf('%s:%s missing %s columns for %s horizon %d.', ...
                        file, sheet, mat2str(doc_nums(isnan(col_idx))), root, horizon); %#ok<AGROW>
                    continue;
                end

                row_idx = find(id_mask);
                prob = prob_all(row_idx, col_idx);
                row_sum = sum(prob, 2, 'omitnan');
                keep = isfinite(row_sum) & row_sum > 0;
                if ~any(keep)
                    continue;
                end
                prob = prob(keep, :);
                out_dates = dates_all(row_idx(keep));

                order = regime.doc_to_ascending_order;
                prob = prob(:, order);
                bin_edges = regime.bin_edges;

                [prob, normalize_warnings] = validate_prob(prob, file, sheet, root, horizon);
                warnings = [warnings, normalize_warnings]; %#ok<AGROW>

                [ok_bins, bin_msg] = validate_bins(bin_edges);
                if ~ok_bins
                    warnings{end + 1} = sprintf('%s:%s invalid official bins for %s h%d (%s): %s', ...
                        file, sheet, root, horizon, regime.label, bin_msg); %#ok<AGROW>
                    continue;
                end

                [out_dates, date_order] = sort(out_dates);
                prob = prob(date_order, :);
                [out_dates, unique_idx] = unique(out_dates, 'stable');
                if numel(unique_idx) < size(prob, 1)
                    warnings{end + 1} = sprintf('%s:%s duplicate survey dates collapsed for %s ID %s h%d.', ...
                        file, sheet, root, char(ids(id_idx)), horizon); %#ok<AGROW>
                end
                prob = prob(unique_idx, :);

                if ~issorted(out_dates)
                    warnings{end + 1} = sprintf('%s:%s dates could not be sorted for %s ID %s h%d.', ...
                        file, sheet, root, char(ids(id_idx)), horizon); %#ok<AGROW>
                    continue;
                end

                series(end + 1) = struct( ... %#ok<AGROW>
                    'name', root, ...
                    'horizon', horizon, ...
                    'dates', out_dates(:), ...
                    'bin_edges', bin_edges, ...
                    'prob', prob, ...
                    'realized', NaN(numel(out_dates), 1), ...
                    'forecaster_id', char(ids(id_idx)), ...
                    'vintage', NaT(numel(out_dates), 1), ...
                    'source_file', file, ...
                    'source_sheet', sheet);
            end
        end
    end

    if isempty(series)
        warnings{end + 1} = sprintf('%s:%s recognized %s columns but found no nonempty probability rows.', ...
            file, sheet, root); %#ok<AGROW>
    end
end
end

function name = first_exact_match(vars, lower_vars, pattern)
hit = strcmp(lower_vars, lower(pattern));
if any(hit)
    name = vars{find(hit, 1, 'first')};
else
    name = '';
end
end

function [cols, nums] = philly_probability_columns(vars, root)
cols = {};
nums = [];
pattern = ['^', root, '(\d+)$'];
for i = 1:numel(vars)
    token = regexp(upper(vars{i}), pattern, 'tokens', 'once');
    if ~isempty(token)
        cols{end + 1} = vars{i}; %#ok<AGROW>
        nums(end + 1) = str2double(token{1}); %#ok<AGROW>
    end
end
[nums, order] = sort(nums);
cols = cols(order);
end

function regimes = philly_probability_regimes(root)
switch root
    case 'PRGDP'
        regimes = [
            make_regime('1968Q4_1973Q1', 1968, 4, 1973, 1, 15, 1, prpgdp_edges('1968Q4_1973Q1'))
            make_regime('1973Q2_1974Q3', 1973, 2, 1974, 3, 15, 1, prpgdp_edges('1973Q2_1974Q3'))
            make_regime('1974Q4_1981Q2', 1974, 4, 1981, 2, 15, 1, prpgdp_edges('1974Q4_1981Q2'))
            make_regime('1981Q3_1991Q4', 1981, 3, 1991, 4, 6, 2, edges_ascending([6 Inf; 4 5.9; 2 3.9; 0 1.9; -2 -0.1; -Inf -2]))
            make_regime('1992Q1_2009Q1', 1992, 1, 2009, 1, 10, 2, edges_ascending([6 Inf; 5 5.9; 4 4.9; 3 3.9; 2 2.9; 1 1.9; 0 0.9; -1 -0.1; -2 -1.1; -Inf -2]))
            make_regime('2009Q2_2020Q1', 2009, 2, 2020, 1, 11, 4, edges_ascending([6 Inf; 5 5.9; 4 4.9; 3 3.9; 2 2.9; 1 1.9; 0 0.9; -1 -0.1; -2 -1.1; -3 -2.1; -Inf -3]))
            make_regime('2020Q2_2024Q1', 2020, 2, 2024, 1, 11, 4, edges_ascending([16 Inf; 10 15.9; 7 9.9; 4 6.9; 2.5 3.9; 1.5 2.4; 0 1.4; -3 -0.1; -6 -3.1; -12 -6.1; -Inf -12]))
            make_regime('2024Q2_present', 2024, 2, 9999, 4, 11, 4, edges_ascending([9 Inf; 7 8.9; 5.5 6.9; 4 5.4; 2.5 3.9; 1.5 2.4; 0 1.4; -1.5 -0.1; -3 -1.6; -5.1 -3.1; -Inf -5.1]))
            ];
    case 'PRPGDP'
        regimes = [
            make_regime('1968Q4_1973Q1', 1968, 4, 1973, 1, 15, 1, prpgdp_edges('1968Q4_1973Q1'))
            make_regime('1973Q2_1974Q3', 1973, 2, 1974, 3, 15, 1, prpgdp_edges('1973Q2_1974Q3'))
            make_regime('1974Q4_1981Q2', 1974, 4, 1981, 2, 15, 1, prpgdp_edges('1974Q4_1981Q2'))
            make_regime('1981Q3_1985Q1', 1981, 3, 1985, 1, 6, 2, edges_ascending([12 Inf; 10 11.9; 8 9.9; 6 7.9; 4 5.9; -Inf 4]))
            make_regime('1985Q2_1991Q4', 1985, 2, 1991, 4, 6, 2, edges_ascending([10 Inf; 8 9.9; 6 7.9; 4 5.9; 2 3.9; -Inf 2]))
            make_regime('1992Q1_2013Q4', 1992, 1, 2013, 4, 10, 2, edges_ascending([8 Inf; 7 7.9; 6 6.9; 5 5.9; 4 4.9; 3 3.9; 2 2.9; 1 1.9; 0 0.9; -Inf 0]))
            make_regime('2014Q1_present', 2014, 1, 9999, 4, 10, 2, edges_ascending([4 Inf; 3.5 3.9; 3 3.4; 2.5 2.9; 2 2.4; 1.5 1.9; 1 1.4; 0.5 0.9; 0 0.4; -Inf 0]))
            ];
    case 'PRUNEMP'
        regimes = [
            make_regime('2009Q2_2013Q4', 2009, 2, 2013, 4, 10, 4, edges_ascending([11 Inf; 10 10.9; 9.5 9.9; 9 9.4; 8.5 8.9; 8 8.4; 7.5 7.9; 7 7.4; 6 6.9; -Inf 6]))
            make_regime('2014Q1_2020Q1', 2014, 1, 2020, 1, 10, 4, edges_ascending([9 Inf; 8 8.9; 7.5 7.9; 7 7.4; 6.5 6.9; 6 6.4; 5.5 5.9; 5 5.4; 4 4.9; -Inf 4]))
            make_regime('2020Q2_2024Q1', 2020, 2, 2024, 1, 10, 4, edges_ascending([15 Inf; 12 14.9; 10 11.9; 8 9.9; 7 7.9; 6 6.9; 5 5.9; 4 4.9; 3 3.9; -Inf 3]))
            make_regime('2024Q2_present', 2024, 2, 9999, 4, 10, 4, edges_ascending([9.9 Inf; 8.3 9.8; 7.2 8.2; 6.1 7.1; 5.5 6.0; 4.9 5.4; 4.3 4.8; 3.7 4.2; 3.1 3.6; -Inf 3.1]))
            ];
    otherwise
        regimes = struct([]);
end
end

function regime = make_regime(label, start_year, start_quarter, end_year, end_quarter, k_bins, n_horizons, bin_edges)
regime = struct();
regime.label = label;
regime.start_date = datetime(start_year, (start_quarter - 1) * 3 + 1, 1);
regime.end_date = datetime(end_year, (end_quarter - 1) * 3 + 1, 1);
regime.k_bins = k_bins;
regime.n_horizons = n_horizons;
regime.bin_edges = bin_edges;
regime.doc_to_ascending_order = k_bins:-1:1;
end

function edges = prpgdp_edges(label)
switch label
    case '1968Q4_1973Q1'
        edges = edges_ascending([10 Inf; 9 9.9; 8 8.9; 7 7.9; 6 6.9; 5 5.9; 4 4.9; 3 3.9; 2 2.9; 1 1.9; 0 0.9; -1 -0.1; -2 -1.1; -3 -2.1; -Inf -3]);
    case '1973Q2_1974Q3'
        edges = edges_ascending([12 Inf; 11 11.9; 10 10.9; 9 9.9; 8 8.9; 7 7.9; 6 6.9; 5 5.9; 4 4.9; 3 3.9; 2 2.9; 1 1.9; 0 0.9; -1 -0.1; -Inf -1]);
    case '1974Q4_1981Q2'
        edges = edges_ascending([16 Inf; 15 15.9; 14 14.9; 13 13.9; 12 12.9; 11 11.9; 10 10.9; 9 9.9; 8 8.9; 7 7.9; 6 6.9; 5 5.9; 4 4.9; 3 3.9; -Inf 3]);
    otherwise
        edges = [];
end
end

function edges = edges_ascending(descending_edges)
[~, order] = sort(descending_edges(:, 1));
edges = descending_edges(order, :);
end

function [bin_edges, bin_key, warnings] = long_bin_edges(lower, upper, file, sheet)
warnings = {};
pairs = unique([lower(:), upper(:)], 'rows');
[~, order] = sort(pairs(:, 1));
pairs = pairs(order, :);

if isempty(pairs) || any(~isfinite(pairs(:))) || any(pairs(:, 1) >= pairs(:, 2))
    bin_edges = [];
    bin_key = [];
    warnings{end + 1} = sprintf('%s:%s long-format bin edges could not be inferred.', file, sheet);
    return;
end

if size(pairs, 1) > 1 && any(pairs(2:end, 1) < pairs(1:(end - 1), 2))
    bin_edges = [];
    bin_key = [];
    warnings{end + 1} = sprintf('%s:%s long-format bin endpoints overlap.', file, sheet);
    return;
end

contiguous = size(pairs, 1) == 1 || all(abs(pairs(1:(end - 1), 2) - pairs(2:end, 1)) < 1e-12);
if contiguous
    bin_edges = [pairs(:, 1); pairs(end, 2)];
else
    bin_edges = pairs;
    warnings{end + 1} = sprintf('%s:%s long-format bins are not contiguous; storing K-by-2 endpoints.', ...
        file, sheet);
end
bin_key = pairs;
end

function key = datetime_key(dt)
if isnat(dt)
    key = "NaT";
else
    key = string(datestr(dt, 'yyyymmdd'));
end
end

function tbl = normalize_table(tbl)
tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings( ...
    matlab.lang.makeValidName(tbl.Properties.VariableNames));

empty_vars = false(1, width(tbl));
for i = 1:width(tbl)
    col = tbl.(i);
    if all(ismissing_compat(col))
        empty_vars(i) = true;
    end
end
tbl(:, empty_vars) = [];
end

function roles = detect_roles(vars)
lower_vars = lower(vars);
roles = struct();
roles.date = first_match(vars, lower_vars, {'date', 'surveydate', 'targetdate', 'quarter', 'yearqtr', 'yearquarter'});
roles.name = first_match(vars, lower_vars, {'variable', 'var', 'series', 'name', 'indicator'});
roles.horizon = first_match(vars, lower_vars, {'horizon', 'h', 'forecast_horizon', 'forecasthorizon'});
roles.realized = first_match(vars, lower_vars, {'realized', 'realised', 'actual', 'realization', 'realisation', 'outturn'});
roles.forecaster_id = first_match(vars, lower_vars, {'forecaster', 'forecaster_id', 'id', 'respondent', 'panelist'});
roles.vintage = first_match(vars, lower_vars, {'vintage', 'vintagedate', 'release', 'realtime'});
roles.bin_lower = first_match(vars, lower_vars, {'bin_lower', 'binlow', 'bin_low', 'lower', 'lowerbound', 'lower_bound', 'left', 'from'});
roles.bin_upper = first_match(vars, lower_vars, {'bin_upper', 'binupper', 'bin_high', 'binhigh', 'upper', 'upperbound', 'upper_bound', 'right', 'to'});

reserved = {roles.date, roles.name, roles.horizon, roles.realized, ...
    roles.forecaster_id, roles.vintage, roles.bin_lower, roles.bin_upper};
roles.prob = detect_probability_columns(vars, lower_vars, reserved);
end

function name = first_match(vars, lower_vars, patterns)
name = '';
for i = 1:numel(patterns)
    hit = strcmp(lower_vars, lower(patterns{i}));
    if any(hit)
        name = vars{find(hit, 1, 'first')};
        return;
    end
end
for i = 1:numel(patterns)
    hit = contains(lower_vars, lower(patterns{i}));
    if any(hit)
        name = vars{find(hit, 1, 'first')};
        return;
    end
end
end

function prob_cols = detect_probability_columns(vars, lower_vars, reserved)
reserved = reserved(~cellfun(@isempty, reserved));
is_reserved = ismember(vars, reserved);
prob_like = contains(lower_vars, 'prob') | contains(lower_vars, 'density') | ...
    contains(lower_vars, 'bin') | ~cellfun(@isempty, regexp(lower_vars, '^p\d+', 'once'));
prob_cols = vars(prob_like & ~is_reserved);

if isempty(prob_cols)
    numeric_candidates = vars(~is_reserved);
    keep = false(size(numeric_candidates));
    for i = 1:numel(numeric_candidates)
        keep(i) = ~isempty(regexp(numeric_candidates{i}, '(-?\d+(\.\d+)?)', 'once'));
    end
    prob_cols = numeric_candidates(keep);
end
end

function groups = table_groups(tbl, group_cols)
groups = struct('idx', {});
if isempty(group_cols)
    groups(1).idx = true(height(tbl), 1);
    return;
end

keys = strings(height(tbl), 1);
for i = 1:numel(group_cols)
    keys = keys + "|" + string(tbl.(group_cols{i}));
end
[~, ~, gidx] = unique(keys, 'stable');
for g = 1:max(gidx)
    groups(g).idx = gidx == g; %#ok<AGROW>
end
end

function x = table_to_matrix(tbl, cols)
x = NaN(height(tbl), numel(cols));
for i = 1:numel(cols)
    x(:, i) = numeric_column(tbl.(cols{i}));
end
end

function x = numeric_column(col)
if isnumeric(col)
    x = double(col);
elseif iscell(col)
    x = str2double(string(col));
elseif isstring(col) || ischar(col) || iscategorical(col)
    x = str2double(string(col));
elseif isdatetime(col)
    x = datenum(col);
else
    x = NaN(numel(col), 1);
end
x = x(:);
end

function dates = parse_dates(col)
if isdatetime(col)
    dates = col(:);
    return;
end

if isnumeric(col)
    x = double(col(:));
    dates = NaT(size(x));
    qmask = x > 10000 & x < 99999;
    years = floor(x(qmask) ./ 10);
    quarters = round(x(qmask) - years .* 10);
    valid_q = quarters >= 1 & quarters <= 4;
    q_idx = find(qmask);
    dates(q_idx(valid_q)) = datetime(years(valid_q), (quarters(valid_q) - 1) * 3 + 1, 1);

    serial = ~qmask & isfinite(x);
    try
        dates(serial) = datetime(x(serial), 'ConvertFrom', 'excel');
    catch
        try
            dates(serial) = datetime(x(serial), 'ConvertFrom', 'datenum');
        catch
        end
    end
    return;
end

txt = string(col);
dates = NaT(size(txt));
for i = 1:numel(txt)
    s = strtrim(txt(i));
    token = regexp(s, '(\d{4})\s*[Qq]\s*([1-4])', 'tokens', 'once');
    if isempty(token)
        token = regexp(s, '(\d{4})([1-4])$', 'tokens', 'once');
    end
    if ~isempty(token)
        yy = str2double(token{1});
        qq = str2double(token{2});
        dates(i) = datetime(yy, (qq - 1) * 3 + 1, 1);
        continue;
    end
    try
        dates(i) = datetime(s);
    catch
    end
end
dates = dates(:);
end

function [bin_edges, order, warnings] = detect_bin_edges(prob_cols)
warnings = {};
tokens = NaN(numel(prob_cols), 2);
order = (1:numel(prob_cols))';
for i = 1:numel(prob_cols)
    nums = regexp(prob_cols{i}, '-?\d+(\.\d+)?', 'match');
    if numel(nums) >= 2
        tokens(i, 1) = str2double(nums{1});
        tokens(i, 2) = str2double(nums{2});
    elseif numel(nums) == 1
        tokens(i, 1) = str2double(nums{1});
    end
end

if all(isfinite(tokens(:, 1))) && all(isfinite(tokens(:, 2)))
    bin_edges = tokens;
    [~, order] = sort(bin_edges(:, 1));
    bin_edges = bin_edges(order, :);
elseif all(isfinite(tokens(:, 1))) && numel(prob_cols) > 1
    starts = tokens(:, 1);
    [~, order] = sort(starts);
    values = tokens(order, 1);
    step = median(diff(values));
    if isfinite(step) && step > 0
        bin_edges = [values; values(end) + step];
    else
        bin_edges = [];
    end
else
    bin_edges = (0:numel(prob_cols))';
    warnings{end + 1} = sprintf(['WEAK_BINS: Bin labels do not contain numeric ' ...
        'edges; using ordinal bin edges for probability columns: %s'], ...
        strjoin(string(prob_cols), ', '));
end
end

function [ok, msg] = validate_bins(bin_edges)
ok = true;
msg = '';
if isvector(bin_edges)
    edges = bin_edges(:);
    ok = numel(edges) >= 2 && all(~isnan(edges)) && all(diff(edges) > 0);
else
    ok = size(bin_edges, 2) == 2 && all(~isnan(bin_edges(:))) && ...
        all(bin_edges(:, 1) < bin_edges(:, 2));
end
if ~ok
    msg = 'bin edges must be strictly increasing or endpoints lower<upper';
end
end

function [prob, warnings] = validate_prob(prob, file, sheet, name, horizon)
warnings = {};
prob(prob < 0 & prob > -1e-12) = 0;
row_sum = sum(prob, 2, 'omitnan');
bad = ~isfinite(row_sum) | row_sum <= 0;
prob(bad, :) = NaN;

scale100 = row_sum > 99 & row_sum < 101;
if any(scale100)
    prob(scale100, :) = prob(scale100, :) ./ 100;
    row_sum(scale100) = row_sum(scale100) ./ 100;
end

needs_norm = isfinite(row_sum) & row_sum > 0 & abs(row_sum - 1) > 1e-6;
if any(needs_norm)
    prob(needs_norm, :) = bsxfun(@rdivide, prob(needs_norm, :), row_sum(needs_norm));
    warnings{end + 1} = sprintf('%s:%s %s h%s probability rows renormalized.', ...
        file, sheet, name, num2str(horizon));
end

final_sum = sum(prob, 2, 'omitnan');
final_ok = isfinite(final_sum) & final_sum > 0;
prob(final_ok, :) = bsxfun(@rdivide, prob(final_ok, :), final_sum(final_ok));
end

function tf = ismissing_compat(col)
try
    tf = ismissing(col);
catch
    if isnumeric(col)
        tf = isnan(col);
    else
        tf = false(size(col));
    end
end
end

function s = first_string(col)
vals = string(col);
vals = vals(~ismissing(vals) & strlength(strtrim(vals)) > 0);
if isempty(vals)
    s = '';
else
    s = char(vals(1));
end
end

function x = first_numeric(col)
vals = numeric_column(col);
vals = vals(isfinite(vals));
if isempty(vals)
    x = NaN;
else
    x = vals(1);
end
end

function name = infer_name_from_file(file)
[~, base] = fileparts(file);
base_upper = upper(base);
known = {'RGDP', 'GDPD', 'UNR', 'CPI', 'GDP', 'PCE'};
name = '';
for i = 1:numel(known)
    if contains(base_upper, known{i})
        name = known{i};
        return;
    end
end
end

function h = infer_horizon_from_text(file)
[~, base] = fileparts(file);
tok = regexp(base, '[Hh](\d+)', 'tokens', 'once');
if isempty(tok)
    tok = regexp(base, 'horizon[_-]?(\d+)', 'tokens', 'once');
end
if isempty(tok)
    h = NaN;
else
    h = str2double(tok{1});
end
end
