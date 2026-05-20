function S90_export_outputs(cfg)
%S90_EXPORT_OUTPUTS Export final tables and figures.
%
% Placeholder for paper-ready output export. Generated files should be written
% under cfg.tables and cfg.figures, both inside ignored out/.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.tables);
ensure_dir(cfg.figures);

pretty_print('Export step is a placeholder; no paper outputs written.', 'warn');
end
