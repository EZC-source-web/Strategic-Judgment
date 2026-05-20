function pretty_print(message, level)
%PRETTY_PRINT Print a compact timestamped status message.

if nargin < 2 || isempty(level)
    level = 'info';
end

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
fprintf('[%s] %-4s %s\n', timestamp, upper(char(level)), char(message));
end
