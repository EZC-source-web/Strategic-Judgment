function ensure_dir(pathname)
%ENSURE_DIR Create a directory if it does not already exist.

if nargin < 1 || isempty(pathname)
    error('ensure_dir:InvalidInput', 'Pathname must be a non-empty string.');
end

if exist(pathname, 'dir') ~= 7
    [ok, msg] = mkdir(pathname);
    if ~ok
        error('ensure_dir:CreateFailed', ...
            'Could not create directory "%s": %s', pathname, msg);
    end
end
end
