function rev = psm_isReversed(ref, vertical)
%PSM_ISREVERSED  True if the red end of the rainbow comes first in the photo.
%   Uses the blue and red centroids found by psm_loadPhoto. If either is
%   missing, assumes blue comes first.
rev = false;
if any(isnan(ref.blue)) || any(isnan(ref.red)), return; end
if vertical
    rev = ref.blue(1) > ref.red(1);
else
    rev = ref.blue(2) > ref.red(2);
end
end
