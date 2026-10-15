function cal = psm_calibration(type, pix, nm, order)
%PSM_CALIBRATION  Build a pixel -> wavelength calibration.
%   cal = psm_calibration('none')
%   cal = psm_calibration('laser', pix, nm, order)
%         known lines (laser spots, lamp lines) at positions pix along the
%         strip; order 1 = grating (straight line), 2 = prism (curve)
%   cal = psm_calibration('model', pix, nm)
%         prism dispersion model  pix = a + b / nm^2  fitted to absorption
%         peaks of samples with known lambda_max. NOT independent: use only
%         when no laser calibration exists, and say so when reporting.
%
%   Use x = psm_wavelength(cal, 1:n) to convert positions to nm.
cal = struct('type', type, 'p', [], 'resid', [], 'info', '');
switch lower(type)
    case 'none'
        cal.info = 'No calibration: x-axis in pixels (blue -> red).';
    case 'laser'
        if nargin < 4, order = 1; end
        order = min(order, numel(pix) - 1);
        cal.p = polyfit(pix(:), nm(:), order);
        cal.resid = nm(:)' - polyval(cal.p, pix(:)');
        if numel(pix) > order + 1
            cal.info = sprintf('Laser calibration (order %d), residuals %s nm.', order, mat2str(round(cal.resid, 1)));
        else
            cal.info = sprintf('Laser calibration (order %d), exact fit - add a line to check accuracy.', order);
        end
    case 'model'
        X = [ones(numel(pix), 1), 1 ./ nm(:).^2];
        cal.p = X \ pix(:);                       % [a; b]
        cal.resid = psm_wavelength(cal, pix(:)') - nm(:)';
        cal.info = sprintf(['Estimated axis (prism model fitted to known peaks), residuals %s nm. ', ...
                            'Not an independent calibration.'], mat2str(round(cal.resid, 1)));
    otherwise
        error('psm:cal', 'Unknown calibration type "%s".', type);
end
end
