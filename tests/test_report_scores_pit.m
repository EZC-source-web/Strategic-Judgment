%TEST_REPORT_SCORES_PIT Lightweight test for report PIT/logscore step.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'scripts'));
addpath(genpath(fullfile(root, 'src')));

cfg = default_config();
if exist(cfg.spf.realized_file, 'file') ~= 2
    fprintf('SKIP test_report_scores_pit: missing realized cache: %s\n', cfg.spf.realized_file);
    return;
end

report = S30_compute_scores_pit(cfg);
assert(isfield(report, 'series') && ~isempty(report.series), ...
    'Report series should be non-empty.');

for j = 1:numel(report.series)
    s = report.series(j);
    finite_pit = isfinite(s.pit);
    assert(all(s.pit(finite_pit) >= 0 & s.pit(finite_pit) <= 1), ...
        'Finite PIT values must lie in [0,1].');
    assert(all(isfinite(s.logscore(finite_pit))), ...
        'Logscore should be finite wherever PIT is finite.');
end

fprintf('PASS test_report_scores_pit: computed %d report series.\n', numel(report.series));
