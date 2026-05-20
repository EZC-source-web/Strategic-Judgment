function crps = crps_from_cdfgrid(grid, cdf_values, y)
%CRPS_FROM_CDFGRID Continuous ranked probability score on a CDF grid.
%
% crps = CRPS_FROM_CDFGRID(grid, cdf_values, y)
%
% TODO: Implement numerical integration of
%   integral (F(x) - 1{x >= y})^2 dx
% on each forecast grid. The signature is fixed so downstream code can call it
% once the empirical density representation is finalized.

grid = grid(:); %#ok<NASGU>
cdf_values = cdf_values; %#ok<NASGU>
y = y(:);

crps = NaN(size(y));
warning('crps_from_cdfgrid:NotImplemented', ...
    'CRPS calculation is a documented placeholder.');
end
