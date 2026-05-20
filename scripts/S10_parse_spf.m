function S10_parse_spf(cfg)
%S10_PARSE_SPF Parse SPF density forecasts into a standardized cache file.

if nargin < 1
    cfg = default_config();
end

ensure_dir(cfg.cache);

spf = parse_spf_densities(cfg.spf.raw_dir, cfg);
print_spf_summary(spf);
save_mat(cfg.spf.standardized_file, 'spf', spf);

pretty_print(sprintf('Saved SPF cache: %s', cfg.spf.standardized_file), 'info');
end

function print_spf_summary(spf)
series = spf.series;
if isempty(series)
    pretty_print(sprintf('SPF summary: status=%s, series=0', spf.meta.status), 'warn');
    return;
end

horizons = unique([series.horizon]);
k = arrayfun(@(s) size(s.prob, 2), series);

all_dates = vertcat(series.dates);
all_dates = all_dates(~isnat(all_dates));
if isempty(all_dates)
    date_msg = 'dates=n/a';
else
    date_msg = sprintf('dates=%s..%s', datestr(min(all_dates), 'yyyy-mm-dd'), ...
        datestr(max(all_dates), 'yyyy-mm-dd'));
end

pretty_print(sprintf('SPF summary: status=%s, series=%d, horizons=%s, %s, typical K=%g', ...
    spf.meta.status, numel(series), mat2str(horizons), date_msg, median(k)), 'info');
end
