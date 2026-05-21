function cfg = default_config()
%DEFAULT_CONFIG Return project configuration and cross-platform paths.

root = project_root();

cfg = struct();
cfg.root = root;
cfg.config = fullfile(root, 'config');
cfg.scripts = fullfile(root, 'scripts');
cfg.src = fullfile(root, 'src');

cfg.data = fullfile(root, 'data');
cfg.data_raw = fullfile(cfg.data, 'raw');

cfg.out = fullfile(root, 'out');
cfg.cache = fullfile(cfg.out, 'cache');
cfg.logs = fullfile(cfg.out, 'logs');
cfg.figures = fullfile(cfg.out, 'figures');
cfg.tables = fullfile(cfg.out, 'tables');
cfg.bundles = fullfile(cfg.out, 'bundles');
cfg.bundle_mirror_dirs = find_bundle_mirror_dirs();

cfg.paper = fullfile(root, 'paper');
cfg.tests = fullfile(root, 'tests');

cfg.paper_title = 'The judgmental strategy of professional forecasters';
cfg.matlab_min_version = '9.5'; % R2018b

cfg.spf = struct();
cfg.spf.raw_dir = fullfile(cfg.data_raw, 'spf');
cfg.spf.standardized_file = fullfile(cfg.cache, 'spf_densities.mat');

cfg.benchmarks = struct();
cfg.benchmarks.cache_file = fullfile(cfg.cache, 'benchmark_forecasts.mat');

cfg.scores = struct();
cfg.scores.cache_file = fullfile(cfg.cache, 'scores_pit.mat');

cfg.ss_tests = struct();
cfg.ss_tests.cache_file = fullfile(cfg.cache, 'ss_starx_tests.mat');
cfg.ss_tests.default_lags = 2;
cfg.ss_tests.default_delay = 1;
cfg.ss_tests.include_const = true;
end

function dirs = find_bundle_mirror_dirs()
%FIND_BUNDLE_MIRROR_DIRS Optional local folders for review ZIP copies.

home_dir = getenv('HOME');
if isempty(home_dir)
    home_dir = getenv('USERPROFILE');
end
if isempty(home_dir)
    dirs = {};
    return;
end

candidates = {
    fullfile(home_dir, 'Library', 'CloudStorage', 'Dropbox', 'StrategicJudgment', 'Submission_RESTUD')
    fullfile(home_dir, 'Library', 'CloudStorage', 'Dropbox', 'StrategicJudgment', 'Submission_Restud')
    fullfile(home_dir, 'Library', 'CloudStorage', 'Dropbox', 'Submission_RESTUD')
    fullfile(home_dir, 'Library', 'CloudStorage', 'Dropbox', 'Submission_Restud')
    fullfile(home_dir, 'Dropbox', 'StrategicJudgment', 'Submission_RESTUD')
    fullfile(home_dir, 'Dropbox', 'StrategicJudgment', 'Submission_Restud')
    fullfile(home_dir, 'Dropbox', 'Submission_RESTUD')
    fullfile(home_dir, 'Dropbox', 'Submission_Restud')
    };

dirs = {};
for i = 1:numel(candidates)
    if exist(candidates{i}, 'dir') == 7
        dirs = candidates(i);
        return;
    end
end
end
