function pk = psm_findPeaks(pr, nMax, minSep, thr)
%PSM_FINDPEAKS  Positions of the brightest separate peaks (e.g. laser spots).
%   pk = psm_findPeaks(profile, n)   returns up to n peak positions, sorted.
%   minSep  minimum distance between peaks in pixels (default 10)
%   thr     minimum height as fraction of the highest peak (default 0.2)
if nargin < 3, minSep = 10; end
if nargin < 4, thr = 0.2; end
p = pr(:)';  p = p - min(p);
if max(p) <= 0, pk = []; return; end
p = p / max(p);
cand = find(p(2:end-1) > p(1:end-2) & p(2:end-1) >= p(3:end) & p(2:end-1) > thr) + 1;
[~, o] = sort(p(cand), 'descend');  cand = cand(o);
pk = zeros(1, 0);
for i = cand
    if all(abs(pk - i) >= minSep), pk(end+1) = i; end %#ok<AGROW>
    if numel(pk) >= nMax, break; end
end
pk = sort(pk);
end
