function [A, valid] = psm_absorbance(Is, Iref, minRefFrac)
%PSM_ABSORBANCE  A = -log10(I_sample / I_reference).
%   Points where the reference is dimmer than minRefFrac * its maximum are
%   set to NaN (the dim ends of the rainbow give unreliable ratios).
if nargin < 3, minRefFrac = 0.3; end
T = Is ./ Iref;
A = -log10(max(T, 1e-3));
valid = Iref > minRefFrac * max(Iref);
A(~valid) = NaN;
end
