function [shift, ok] = psm_shift(P, ref, align)
%PSM_SHIFT  Offset [dy dx] of photo P relative to the reference.
%   Uses the blue end of the rainbow as a landmark, so small movements of
%   the phone or screen between photos do not move the strip off the
%   rainbow. ok = false if no blue spot was found (shift is then [0 0]).
shift = [0 0];  ok = true;
if nargin < 3 || ~align, return; end
if any(isnan(P.blue)) || any(isnan(ref.blue)), ok = false; return; end
shift = P.blue - ref.blue;
end
