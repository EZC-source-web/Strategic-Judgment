function test_spf_parser()
%TEST_SPF_PARSER Lightweight parser test. Skips when raw data are absent.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(genpath(fullfile(root, 'src')));

cfg = default_config();

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
