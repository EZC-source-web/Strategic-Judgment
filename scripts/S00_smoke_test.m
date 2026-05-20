function S00_smoke_test(cfg)
%S00_SMOKE_TEST Verify the core STAR linearity test executes end-to-end.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

rng(12345);
T = 240;
eps = 0.35 * randn(T, 1);
y = zeros(T, 1);
y(1:2) = eps(1:2);

for t = 3:T
    transition = 1 / (1 + exp(-4 * y(t - 2)));
    y(t) = 0.45 * y(t - 1) - 0.20 * y(t - 2) ...
        + 0.30 * y(t - 1) * transition + eps(t);
end

out = lstar_linearity_test(y, 2, 1, true);

assert(isfield(out, 'F_stat'), 'Smoke test missing F_stat.');
assert(isfield(out, 'LM_stat'), 'Smoke test missing LM_stat.');
assert(isfinite(out.F_stat), 'Smoke test produced non-finite F_stat.');
assert(isfinite(out.LM_stat), 'Smoke test produced non-finite LM_stat.');

pretty_print(sprintf('Smoke test passed: F=%.4f, p=%.4g, LM=%.4f, p=%.4g', ...
    out.F_stat, out.F_pvalue, out.LM_stat, out.LM_pvalue), 'ok');
end
