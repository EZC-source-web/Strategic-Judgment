function S10_parse_spf(cfg)
%S10_PARSE_SPF Parse SPF density forecasts into a standardized cache file.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

spf = parse_spf_densities(cfg.spf.raw_dir, cfg);
save_mat(cfg.spf.standardized_file, 'spf', spf);

pretty_print(sprintf('Saved SPF cache: %s', cfg.spf.standardized_file), 'info');
end
