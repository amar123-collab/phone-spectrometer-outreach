function [A, base] = psm_offset(A, mode, win)
%PSM_OFFSET  Optional baseline correction of a phone absorbance spectrum.
%   Only needed when photos were taken with AUTOMATIC exposure; with fixed
%   (Pro / manual) exposure use 'none'.
%
%   'none'     no correction
%   'auto'     subtract a constant: mean of the lowest 15 % of values
%              (assumes the sample is transparent somewhere in the range)
%   'windows'  subtract a straight line fitted in windows where the sample
%              is known to be transparent; win = [f1 f2; f3 f4] as fractions
%              of the strip (0 = blue end, 1 = red end). One row = constant.
if nargin < 2, mode = 'none'; end
n = numel(A);  base = zeros(1, n);
switch lower(mode)
    case 'none'
    case 'auto'
        v = sort(A(~isnan(A)));
        if isempty(v), return; end
        base(:) = mean(v(1:max(1, min(numel(v), round(0.15 * numel(v))))));
    case 'windows'
        m = false(1, n);
        for j = 1:size(win, 1)
            m(max(1, round(win(j, 1) * n)) : min(n, round(win(j, 2) * n))) = true;
        end
        m = m & ~isnan(A);
        if nnz(m) < 3, warning('psm:window', 'Baseline window has no valid points; skipped.'); return; end
        x = 1:n;
        if size(win, 1) >= 2, p = polyfit(x(m), A(m), 1); else, p = mean(A(m)); end
        base = polyval(p, x);
    otherwise
        error('psm:mode', 'Unknown offset mode "%s".', mode);
end
A = A - base;
end
