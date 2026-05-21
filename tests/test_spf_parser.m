function test_spf_parser()
%TEST_SPF_PARSER Lightweight parser test. Skips when raw data are absent.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(genpath(fullfile(root, 'src')));

cfg = default_config();

run_synthetic_wide_test();
run_synthetic_long_test();

if exist(cfg.spf.raw_dir, 'dir') ~= 7 || isempty(dir(fullfile(cfg.spf.raw_dir, '**', '*.*')))
    fprintf('SKIP test_spf_parser: no raw SPF files found in %s\n', cfg.spf.raw_dir);
    return;
end

spf = parse_spf_densities(cfg.spf.raw_dir, cfg);

assert(strcmp(spf.meta.status, 'ok'), 'SPF parser did not return ok status.');
assert(~isempty(spf.series), 'SPF parser returned no series.');

for i = 1:numel(spf.series)
    row_sum = sum(spf.series(i).prob, 2, 'omitnan');
    ok = isfinite(row_sum);
    assert(all(abs(row_sum(ok) - 1) < 1e-6), ...
        'Probability rows are not normalized.');
end

fprintf('PASS test_spf_parser: parsed %d series.\n', numel(spf.series));
end

function run_synthetic_wide_test()
raw_dir = fullfile(tempdir, 'spf_parser_test_wide');
reset_temp_dir(raw_dir);

tbl = table([20201; 20202], {'GDPD'; 'GDPD'}, [2; 2], ...
    [0.5; 50], [0.2; 20], [0.3; 30], [1.1; 1.2], ...
    'VariableNames', {'date', 'name', 'horizon', 'bin_2_3', ...
    'bin_0_1', 'bin_1_2', 'actual'});
writetable(tbl, fullfile(raw_dir, 'spf_wide.csv'));

spf = parse_spf_densities(raw_dir, struct());
assert(strcmp(spf.meta.status, 'ok'), 'Synthetic wide parser did not return ok.');
assert(numel(spf.series) == 1, 'Synthetic wide parser returned wrong series count.');
assert(isequal(spf.series(1).bin_edges, [0 1; 1 2; 2 3]), ...
    'Synthetic wide parser did not sort bin endpoints.');
assert(all(abs(sum(spf.series(1).prob, 2) - 1) < 1e-12), ...
    'Synthetic wide probabilities are not normalized.');
end

function run_synthetic_long_test()
raw_dir = fullfile(tempdir, 'spf_parser_test_long');
reset_temp_dir(raw_dir);

tbl = table([20201; 20201; 20201; 20202; 20202; 20202], ...
    {'RGDP'; 'RGDP'; 'RGDP'; 'RGDP'; 'RGDP'; 'RGDP'}, ...
    [1; 1; 1; 1; 1; 1], ...
    [0; 1; 2; 0; 1; 2], [1; 2; 3; 1; 2; 3], ...
    [20; 30; 50; 0.2; 0.3; 0.5], ...
    [2.1; 2.1; 2.1; 2.2; 2.2; 2.2], ...
    'VariableNames', {'date', 'name', 'horizon', 'bin_low', ...
    'bin_high', 'probability', 'realized'});
writetable(tbl, fullfile(raw_dir, 'spf_long.csv'));

spf = parse_spf_densities(raw_dir, struct());
assert(strcmp(spf.meta.status, 'ok'), 'Synthetic long parser did not return ok.');
assert(numel(spf.series) == 1, 'Synthetic long parser returned wrong series count.');
assert(isequal(spf.series(1).bin_edges(:), [0; 1; 2; 3]), ...
    'Synthetic long parser did not infer contiguous bin edges.');
assert(size(spf.series(1).prob, 1) == 2 && size(spf.series(1).prob, 2) == 3, ...
    'Synthetic long parser did not pivot to T-by-K probabilities.');
assert(all(abs(sum(spf.series(1).prob, 2) - 1) < 1e-12), ...
    'Synthetic long probabilities are not normalized.');
end

function reset_temp_dir(raw_dir)
if exist(raw_dir, 'dir') == 7
    rmdir(raw_dir, 's');
end
mkdir(raw_dir);
end
