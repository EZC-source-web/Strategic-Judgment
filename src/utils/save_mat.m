function save_mat(filename, varargin)
%SAVE_MAT Safely save named variables to a MAT file.
%
% Usage:
%   save_mat(filename, 'name1', value1, 'name2', value2, ...)

if nargin < 3 || mod(numel(varargin), 2) ~= 0
    error('save_mat:InvalidInput', ...
        'Use save_mat(filename, ''name'', value, ...).');
end

out_dir = fileparts(filename);
if ~isempty(out_dir)
    ensure_dir(out_dir);
end

payload = struct();
for i = 1:2:numel(varargin)
    name = varargin{i};
    value = varargin{i + 1};
    if ~ischar(name) && ~isstring(name)
        error('save_mat:InvalidName', 'Variable names must be strings.');
    end
    name = char(name);
    if ~isvarname(name)
        error('save_mat:InvalidName', 'Invalid MATLAB variable name: %s', name);
    end
    payload.(name) = value;
end

tmp = [tempname(out_dir), '.mat'];
save(tmp, '-struct', 'payload', '-v7');

[ok, msg] = movefile(tmp, filename, 'f');
if ~ok
    error('save_mat:MoveFailed', ...
        'Could not move temporary MAT file to "%s": %s', filename, msg);
end
end
