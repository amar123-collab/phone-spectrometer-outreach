function pr = psm_profile(P, strip, shift, smoothPx)
%PSM_PROFILE  Light intensity along the rainbow (always blue -> red).
%   pr = psm_profile(P, strip, [dy dx], smoothPx)
%   P = psm_loadPhoto output, strip = psm_findStrip output,
%   shift = offset of this photo relative to the reference (pixels).
if nargin < 3 || isempty(shift), shift = [0 0]; end
if nargin < 4, smoothPx = 5; end
I = P.I;
r = round(strip.roi(1:2) + shift(1));
c = round(strip.roi(3:4) + shift(2));
if r(1) < 1 || c(1) < 1 || r(2) > size(I, 1) || c(2) > size(I, 2)
    error('psm:outside', ['The strip falls outside photo %s after alignment ', ...
          '(shift %.0f, %.0f px). Was the phone or screen moved a lot?'], P.name, shift(1), shift(2));
end
sub = I(r(1):r(2), c(1):c(2));
if strip.vertical, pr = mean(sub, 2)'; else, pr = mean(sub, 1); end
pr = movmean(double(pr), max(1, smoothPx));
if strip.reverse, pr = fliplr(pr); end
end
