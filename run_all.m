function run_all()
%RUN_ALL Master entry point for the Strategic Judgment replication skeleton.
%
% Run this file from the repository root:
%
%   run_all

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'config'));
addpath(fullfile(root, 'scripts'));
addpath(genpath(fullfile(root, 'src')));

cfg = default_config();

ensure_dir(cfg.out);
ensure_dir(cfg.cache);
ensure_dir(cfg.logs);
ensure_dir(cfg.figures);
ensure_dir(cfg.tables);
ensure_dir(cfg.bundles);

steps = {
    'S00_smoke_test'
    'S10_parse_spf'
    'S15_aggregate_spf'
    'S16_attach_realizations'
    'S20_build_benchmark'
    'S30_compute_scores_pit'
    'S40_run_ss_tests'
    'S90_export_outputs'
    };

pretty_print('Starting replication pipeline.', 'info');

for i = 1:numel(steps)
    step_name = steps{i};
    pretty_print(sprintf('Running %s', step_name), 'info');
    try
        feval(step_name, cfg);
    catch ME
        fprintf(2, '\nPipeline failed in %s.\n', step_name);
        fprintf(2, 'Error: %s\n', ME.message);
        if ~isempty(ME.stack)
            fprintf(2, 'Location: %s, line %d\n', ...
                ME.stack(1).file, ME.stack(1).line);
        end
        rethrow(ME);
    end
end

pretty_print('Replication pipeline finished.', 'info');
end
