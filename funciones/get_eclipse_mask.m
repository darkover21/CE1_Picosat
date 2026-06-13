%% Usage
%
% eclipse_mask = get_eclipse_mask(GMAT_DATA_Path, dt_sec, t_start, t_end)
%
% GMAT_DATA_Path : folder containing EclipseLocator1.txt
% dt_sec         : timestep in seconds (default: 60)
% t_start        : sim start as MATLAB datenum or 'dd mmm yyyy HH:MM:SS' string
% t_end          : sim end   as MATLAB datenum or 'dd mmm yyyy HH:MM:SS' string
%
% If t_start/t_end are omitted the grid spans the eclipse data only,
% which will be shorter than the full simulation.
%
% eclipse_mask is a logical column vector: 1 = eclipse, 0 = sunlight

function eclipse_mask = get_eclipse_mask(GMAT_DATA_Path, dt_sec, t_start, t_end)

if nargin < 2, dt_sec  = 60;  end
if nargin < 3, t_start = [];  end
if nargin < 4, t_end   = [];  end

% convert string inputs to datenum
if ischar(t_start), t_start = datenum(t_start, 'dd mmm yyyy HH:MM:SS'); end
if ischar(t_end),   t_end   = datenum(t_end,   'dd mmm yyyy HH:MM:SS'); end

filepath = fullfile(GMAT_DATA_Path, 'EclipseLocator1.txt');
fid = fopen(filepath, 'r');
if fid == -1
    error('Could not open: %s', filepath);
end

intervals = [];
in_data = false;
pat = ['(\d{2}\s+\w{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+' ...
       '(\d{2}\s+\w{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}(?:\.\d+)?)\s+' ...
       '[\d.]+\s+\w+\s+(\w+)'];

while ~feof(fid)
    line = strtrim(fgetl(fid));
    if isempty(line) || ~ischar(line), continue; end
    if contains(line, 'Start Time (UTC)'), in_data = true; continue; end
    if ~in_data, continue; end
    if strncmp(line, 'Number of events', 16), break; end

    tok = regexp(line, pat, 'tokens');
    if isempty(tok), continue; end
    intervals(end+1, :) = [gmat2dn(tok{1}{1}), gmat2dn(tok{1}{2})]; %#ok<AGROW>
end
fclose(fid);

% use provided bounds or fall back to event span
if isempty(t_start), t_start = min(intervals(:,1)); end
if isempty(t_end),   t_end   = max(intervals(:,2)); end

dt_days      = dt_sec / 86400;
time_vec     = (t_start : dt_days : t_end - dt_days/2)';
eclipse_mask = false(size(time_vec));

for k = 1:size(intervals, 1)
    eclipse_mask = eclipse_mask | (time_vec >= intervals(k,1) & time_vec <= intervals(k,2));
end
end


function dn = gmat2dn(s)
s = strtrim(s);
frac = 0;
if contains(s, '.')
    parts = strsplit(s, '.');
    s    = parts{1};
    frac = str2double(['0.' parts{2}]) / 86400;
end
dn = datenum(s, 'dd mmm yyyy HH:MM:SS') + frac;
end
