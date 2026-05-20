function spf = parse_spf_densities(raw_dir, cfg)
%PARSE_SPF_DENSITIES Parse SPF density forecast files.
%
% spf = PARSE_SPF_DENSITIES(raw_dir, cfg)
%
% Expected future output schema:
%   spf.series(i).name        Variable name, e.g. RGDP, GDPD, UNR.
%   spf.series(i).horizon     Forecast horizon.
%   spf.series(i).dates       Forecast dates.
%   spf.series(i).bin_edges   Histogram bin edges.
%   spf.series(i).prob        T-by-K probability matrix.
%   spf.series(i).realized    T-by-1 realizations.
%
% Raw data should be placed under data/raw/spf/ and must not be committed.

if nargin < 2
    cfg = default_config(); %#ok<NASGU>
end

spf = struct();
spf.meta = struct();
spf.meta.status = 'stub';
spf.meta.raw_dir = raw_dir;
spf.meta.created_by = mfilename();
spf.meta.todo = ['Add Philadelphia Fed SPF density parser once raw file ' ...
    'formats and vintages are fixed.'];
spf.series = struct([]);

if exist(raw_dir, 'dir') ~= 7
    pretty_print(sprintf('SPF raw directory not found yet: %s', raw_dir), ...
        'warn');
else
    files = dir(fullfile(raw_dir, '*'));
    files = files(~[files.isdir]);
    pretty_print(sprintf('SPF parser placeholder found %d raw files.', ...
        numel(files)), 'warn');
end
end
