function S20_build_benchmark(cfg)
%S20_BUILD_BENCHMARK Build benchmark forecast densities.
%
% This is a documented placeholder. Later versions should estimate the paper's
% benchmark model(s) and save standardized predictive densities on grids.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

if exist(cfg.spf.standardized_file, 'file')
    loaded = load(cfg.spf.standardized_file, 'spf'); %#ok<NASGU>
end

bench = struct();
bench.meta = struct();
bench.meta.status = 'stub';
bench.meta.created_by = mfilename();
bench.meta.todo = ['Estimate benchmark densities and save standardized ' ...
    'grid/pdf/cdf objects here.'];

save_mat(cfg.benchmarks.cache_file, 'bench', bench);
pretty_print(sprintf('Saved benchmark placeholder: %s', ...
    cfg.benchmarks.cache_file), 'warn');
end
