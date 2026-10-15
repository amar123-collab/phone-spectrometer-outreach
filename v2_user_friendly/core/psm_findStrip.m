function strip = psm_findStrip(ref, stripFrac)
%PSM_FINDSTRIP  Find the rainbow on the reference photo automatically.
%   strip = psm_findStrip(ref)          ref = output of psm_loadPhoto
%   strip = psm_findStrip(ref, 0.4)     strip thickness as fraction of rainbow
%
%   strip.roi      [row1 row2 col1 col2] on the reference photo
%   strip.vertical true if the rainbow runs up-down in the photo
%   strip.reverse  true if red is on the left/top (profile is then flipped
%                  so that it always runs blue -> red)

if nargin < 2, stripFrac = 0.4; end
k = 4;
Id = double(ref.I(1:k:end, 1:k:end));
Sm = conv2(Id, ones(15) / 225, 'same');
m  = Sm > 0.2 * max(Sm(:));
rows = find(any(m, 2));  cols = find(any(m, 1));
if isempty(rows)
    error('psm:noRainbow', 'No bright rainbow found in the reference photo.');
end
h = rows(end) - rows(1);  w = cols(end) - cols(1);
strip.vertical = h > w;
if ~strip.vertical
    rc = sum(Sm .* m, 2);  ctr = sum((1:numel(rc))' .* rc) / sum(rc);
    roi = [ctr - stripFrac*h/2, ctr + stripFrac*h/2, cols(1) - 0.05*w, cols(end) + 0.05*w];
else
    cc = sum(Sm .* m, 1);  ctr = sum((1:numel(cc)) .* cc) / sum(cc);
    roi = [rows(1) - 0.05*h, rows(end) + 0.05*h, ctr - stripFrac*w/2, ctr + stripFrac*w/2];
end
roi = round(k * roi);
roi = max(roi, 1);
roi(2) = min(roi(2), size(ref.I, 1));
roi(4) = min(roi(4), size(ref.I, 2));
strip.roi = roi;
strip.reverse = psm_isReversed(ref, strip.vertical);
end
