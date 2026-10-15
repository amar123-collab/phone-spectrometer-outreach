function x = psm_wavelength(cal, px)
%PSM_WAVELENGTH  Convert strip positions (pixels) to wavelength (nm).
%   Returns the pixel positions unchanged when there is no calibration.
switch lower(cal.type)
    case 'laser'
        x = polyval(cal.p, px);
    case 'model'
        q = cal.p(2) ./ (px - cal.p(1));
        q(q <= 0) = NaN;
        x = sqrt(q);
    otherwise
        x = px;
end
end
