function S30_compute_scores_pit(cfg)
%S30_COMPUTE_SCORES_PIT Compute scores and PIT diagnostics.
%
% This placeholder preserves the pipeline contract. Once SPF and benchmark
% densities are populated, this step should compute log scores, CRPS, and PITs.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

scores = struct();
scores.meta = struct();
scores.meta.status = 'stub';
scores.meta.created_by = mfilename();
scores.meta.todo = ['Compute report and benchmark scores, PIT values, and ' ...
    'score wedges after parser/benchmark completion.'];

save_mat(cfg.scores.cache_file, 'scores', scores);
pretty_print(sprintf('Saved scores/PIT placeholder: %s', ...
    cfg.scores.cache_file), 'warn');
end
