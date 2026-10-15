function [wl, A] = psm_readSpectrumCSV(file)
%PSM_READSPECTRUMCSV  Read wavelength and absorbance from a spectrometer CSV.
%   Handles UTF-16 (as written by many UV-Vis instruments), UTF-8 and plain
%   text; comma, semicolon or tab separated; header lines are skipped.
%   Uses the first two numeric columns.
fid = fopen(file, 'r');
if fid < 0, error('psm:csv', 'Cannot open %s', file); end
b = fread(fid, Inf, 'uint8=>uint8')';
fclose(fid);
if numel(b) >= 2 && b(1) == 255 && b(2) == 254
    txt = native2unicode(b(3:end), 'UTF-16LE');
elseif numel(b) >= 2 && b(1) == 254 && b(2) == 255
    txt = native2unicode(b(3:end), 'UTF-16BE');
elseif numel(b) >= 3 && b(1) == 239 && b(2) == 187 && b(3) == 191
    txt = native2unicode(b(4:end), 'UTF-8');
elseif numel(b) >= 4 && b(2) == 0 && b(4) == 0
    txt = native2unicode(b, 'UTF-16LE');     % UTF-16 without byte-order mark
else
    txt = native2unicode(b, 'UTF-8');
end
lines = regexp(txt, '\r?\n', 'split');
d = nan(numel(lines), 2);  n = 0;
for i = 1:numel(lines)
    parts = regexp(strtrim(lines{i}), '[,;\t]', 'split');
    if numel(parts) >= 2
        v = str2double(parts(1:2));
        if all(isfinite(v)), n = n + 1;  d(n, :) = v; end
    end
end
if n == 0, error('psm:csv', 'No numeric data found in %s', file); end
wl = d(1:n, 1);  A = d(1:n, 2);
end
