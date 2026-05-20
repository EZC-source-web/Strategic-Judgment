function S40_run_ss_tests(cfg)
%S40_RUN_SS_TESTS Run SS-STARX / STAR linearity tests.
%
% This placeholder keeps the pipeline callable without data. The implemented
% econometric core is src/ss_starx/lstar_linearity_test.m.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

results = struct();
results.meta = struct();
results.meta.status = 'stub';
results.meta.created_by = mfilename();
results.meta.todo = ['Map score/quotation objects to the SS-STARX test ' ...
    'equations and call lstar_linearity_test on empirical series.'];

save_mat(cfg.ss_tests.cache_file, 'results', results);
pretty_print(sprintf('Saved SS test placeholder: %s', ...
    cfg.ss_tests.cache_file), 'warn');
end
