%% run_spectra.m  -  phone-photo absorbance spectra, NO clicks needed
% Everything is set in the SETTINGS block below. Put this script in the same
% folder as the photos (or set 'folder'), then type:  >> run_spectra
%
% What it does
%   1. Loads each photo (applies the phone's rotation flag, undoes JPEG gamma)
%   2. Finds the rainbow on the reference photo automatically (or uses roiFixed)
%   3. Lines up every photo on its blue spot, so small phone/paper movements
%      between shots do not shift the strip
%   4. Averages across the strip -> intensity along the rainbow
%   5. A = -log10( (I_sample - I_dark) / (I_ref - I_dark) )
%   6. Baseline correction in regions where each sample is transparent
%      (needed while photos use automatic exposure; set baselineMode='none' later)
%   7. Saves figures (PNG) and data (CSV: raw and corrected absorbance)
% Base MATLAB only, no toolboxes.

clear; close all;

%% ======================= SETTINGS =======================
folder      = pwd;                          % folder containing the photos
refFile     = 'full.jpg';                   % white light, no sample
darkFile    = '';                           % lamp blocked, SAME camera settings; '' = none
                                            % (dark.jpg from 30 Sept had room light -> do not use)
sampleFiles = {'sample1.jpg','sample2.jpg','sample3.jpg','sample4.jpg','sample5.jpg'};
sampleNames = {'Sample 1 (blue)','Sample 2 (yellow)','Sample 3 (dark blue)', ...
               'Sample 4 (violet)','Sample 5 (pink)'};
lineColors  = [0.17 0.31 0.84; 0.83 0.66 0; 0.04 0.16 0.42; 0.48 0.18 0.82; 0.91 0.25 0.54];

roiMode     = 'auto';                       % 'auto' = find the rainbow; 'fixed' = use roiFixed
roiFixed    = [2150 2230 900 1630];         % [row1 row2 col1 col2] on the reference (upright photo)
stripFrac   = 0.4;                          % auto: strip height as fraction of rainbow height
alignOnBlue = true;                         % shift each photo so its blue spot matches the reference

calPix      = [];                           % calibration: positions along the strip (pixels) ...
calNm       = [];                           % ... and their wavelengths, e.g. [405 532 650]
fitOrder    = 2;                            % 2 = prism, 1 = grating

smoothPx    = 5;                            % moving-average window along the rainbow (pixels)
minRefFrac  = 0.3;                          % ignore the dim ends: reference < 30 % of its maximum

% Baseline correction (removes offsets/tilts caused by unequal AUTOMATIC exposure).
% For each sample: windows (as fractions of the strip, 0 = blue end, 1 = red end)
% where that sample does NOT absorb (checked against the lab UV-Vis spectra).
% Two windows -> straight-line baseline; one window -> constant offset.
% Set baselineMode = 'none' for photos taken with fixed (Pro-mode) exposure.
baselineMode = 'windows';                   % 'windows' or 'none'
baseWin = { [0.10 0.25; 0.86 0.95], ...     % Sample 1: transparent in blue and deep red
            [0.55 0.65; 0.86 0.95], ...     % Sample 2: transparent green -> red
            [0.10 0.25],            ...     % Sample 3: transparent in blue only (absorbs red)
            [0.10 0.25; 0.86 0.95], ...     % Sample 4: transparent in blue and deep red
            [0.10 0.25; 0.86 0.95] };       % Sample 5: transparent in blue and deep red
outName     = 'phone_spectra';              % output file prefix
%% ========================================================

%% Load reference and dark
ref = loadImg(fullfile(folder, refFile));
if ~isempty(darkFile), dark = loadImg(fullfile(folder, darkFile)); end
[refBy, refBx] = blueCentroid(ref.lin);

%% Strip (region of interest) on the reference
if strcmpi(roiMode, 'auto')
    roi = findStrip(ref.I, stripFrac);
else
    roi = roiFixed;
end
fprintf('Strip: rows %d-%d, columns %d-%d (reference photo)\n', roi);

%% Intensity profiles
getProf = @(P, dy, dx) stripProfile(P.I, roi, dy, dx, smoothPx);
Iref = getProf(ref, 0, 0);
Idark_ref = 0;
if ~isempty(darkFile), Idark_ref = getProf(dark, 0, 0); end
Iref = Iref - Idark_ref;
px = 1:numel(Iref);

if ~isempty(calPix)
    p = polyfit(calPix(:), calNm(:), fitOrder);
    x = polyval(p, px);  xlab = 'Wavelength (nm)';
    fprintf('Calibration residuals (nm): %s\n', mat2str(round(calNm(:)' - polyval(p, calPix(:))', 1)));
else
    x = px;  xlab = 'Position along the rainbow (pixels; blue \rightarrow red)';
end
valid = Iref > minRefFrac * max(Iref);

%% Samples
nS = numel(sampleFiles);
Is = zeros(nS, numel(Iref));  A = zeros(nS, numel(Iref));  Araw = A;  shifts = zeros(nS, 2);
imgs = cell(1, nS);
for k = 1:nS
    P = loadImg(fullfile(folder, sampleFiles{k}));
    dy = 0; dx = 0;
    if alignOnBlue
        [by, bx] = blueCentroid(P.lin);
        dy = by - refBy;  dx = bx - refBx;
    end
    shifts(k, :) = [dy dx];
    Is(k, :) = getProf(P, dy, dx) - Idark_ref;
    T = Is(k, :) ./ Iref;
    a = -log10(max(T, 1e-3));  a(~valid) = NaN;
    Araw(k, :) = a;
    if strcmpi(baselineMode, 'windows')
        a = a - baselineFit(a, baseWin{k});
    end
    A(k, :) = a;
    imgs{k} = P.thumb;
    [amax, i] = max(a);
    fprintf('%-22s shift (dy,dx) = (%4.0f,%4.0f) px   peak at x = %.0f   A = %.2f\n', ...
            sampleNames{k}, dy, dx, x(i), amax);
end

%% Figure 1: photos with the strip used
f1 = figure('Color','w','Name','Photos and strip','Position',[50 50 1200 650]);
tiledlayout(f1, 2, ceil((nS+1)/2), 'TileSpacing','compact');
allImgs = [{ref.thumb}, imgs];  allNames = [{'Reference'}, sampleNames];
allShifts = [0 0; shifts];
for k = 1:nS+1
    nexttile; image(allImgs{k}); axis image off; hold on;
    r = (roi + [allShifts(k,1) allShifts(k,1) allShifts(k,2) allShifts(k,2)]) / 4;
    rectangle('Position', [r(3) r(1) r(4)-r(3) r(2)-r(1)], 'EdgeColor','w', 'LineWidth',1.2);
    title(allNames{k}, 'FontWeight','normal');
end

%% Figure 2: light along the rainbow
f2 = figure('Color','w','Name','Intensity','Position',[80 80 750 450]); hold on;
plot(x, Iref, 'k', 'LineWidth', 2, 'DisplayName', 'Reference');
for k = 1:nS
    plot(x, Is(k,:), 'Color', lineColors(k,:), 'LineWidth', 1.5, 'DisplayName', sampleNames{k});
end
xlabel(xlab); ylabel('Intensity (a.u.)'); legend('Box','off'); box off;

%% Figure 3: absorbance
f3 = figure('Color','w','Name','Absorbance','Position',[110 110 750 450]); hold on;
for k = 1:nS
    plot(x, A(k,:), 'Color', lineColors(k,:), 'LineWidth', 2, 'DisplayName', sampleNames{k});
end
yline(0, ':', 'HandleVisibility', 'off');
xlabel(xlab); ylabel('Absorbance  -log_{10}(I/I_{ref})'); legend('Box','off','Location','best'); box off;

%% Save
out = table(px(:), x(:), Iref(:), 'VariableNames', {'pixel','x','I_ref'});
for k = 1:nS
    out.(sprintf('I_S%d', k)) = Is(k,:)';
    out.(sprintf('Araw_S%d', k)) = Araw(k,:)';
    out.(sprintf('A_S%d', k)) = A(k,:)';
end
writetable(out, [outName '.csv']);
exportgraphics(f1, [outName '_photos.png'], 'Resolution', 200);
exportgraphics(f2, [outName '_intensity.png'], 'Resolution', 300);
exportgraphics(f3, [outName '_absorbance.png'], 'Resolution', 300);
fprintf('Saved %s.csv and PNG figures in %s\n', outName, pwd);

%% ======================= FUNCTIONS =======================
function P = loadImg(file)
    raw = imread(file);
    try                                             % phone rotation flag (imread ignores it)
        ws = warning('off', 'all');  info = imfinfo(file);  warning(ws);
        if isfield(info, 'Orientation')
            switch info(1).Orientation
                case 3, raw = rot90(raw, 2);
                case 6, raw = rot90(raw, -1);
                case 8, raw = rot90(raw, 1);
            end
        end
    catch
    end
    if size(raw,3) == 1, raw = repmat(raw, 1, 1, 3); end
    raw = raw(:,:,1:3);
    if isa(raw, 'uint16'), sc = 65535; else, sc = 255; end
    v = single(raw) / sc;
    P.lin = (v <= 0.04045) .* (v / 12.92) + (v > 0.04045) .* (((v + 0.055) / 1.055) .^ 2.4);
    P.I = sum(P.lin, 3);                             % linear intensity
    t = raw(1:4:end, 1:4:end, :);
    if ~isa(t, 'uint8'), t = uint8(double(t) / sc * 255); end
    P.thumb = t;
end

function [cy, cx] = blueCentroid(lin)
    r = lin(:,:,1); g = lin(:,:,2); b = lin(:,:,3);
    v = sort(b(:));  thr = 0.5 * v(round(0.999 * numel(v)));
    w = double(b .* (b > 1.6*r & b > 1.3*g & b > thr));
    if sum(w(:)) == 0, error('No blue spot found - set alignOnBlue = false or use roiMode = ''fixed''.'); end
    tot = sum(w(:));
    cy = sum((1:size(w,1))' .* sum(w, 2)) / tot;    % weighted centroid (memory-light)
    cx = sum((1:size(w,2))  .* sum(w, 1)) / tot;
end

function roi = findStrip(I, stripFrac)
    Id = double(I(1:4:end, 1:4:end));
    S  = conv2(Id, ones(15)/225, 'same');
    m  = S > 0.2 * max(S(:));
    rows = find(any(m, 2));  cols = find(any(m, 1));
    rc = sum(S .* m, 2);  rowC = sum((1:numel(rc))' .* rc) / sum(rc);
    h = rows(end) - rows(1);  w = cols(end) - cols(1);
    roi = round(4 * [rowC - stripFrac*h/2, rowC + stripFrac*h/2, ...
                     cols(1) - 0.05*w,      cols(end) + 0.05*w]);
    roi = max(roi, 1);
    roi([2 4]) = min(roi([2 4]), [size(I,1) size(I,2)]);
end

function b = baselineFit(a, win)
    % Straight line (2 windows) or constant (1 window) fitted where the sample is transparent
    n = numel(a);  m = false(1, n);
    for j = 1:size(win, 1)
        m(max(1, round(win(j,1)*n)) : min(n, round(win(j,2)*n))) = true;
    end
    m = m & ~isnan(a);
    if nnz(m) < 3, b = 0; warning('Baseline window has no valid points - skipped'); return; end
    xx = 1:n;
    if size(win, 1) >= 2, p = polyfit(xx(m), a(m), 1); else, p = mean(a(m)); end
    b = polyval(p, xx);
end

function pr = stripProfile(I, roi, dy, dx, smoothPx)
    r = round(roi(1:2) + dy);  c = round(roi(3:4) + dx);
    if r(1) < 1 || c(1) < 1 || r(2) > size(I,1) || c(2) > size(I,2)
        error('Strip moves outside the photo after alignment - check the photo or use roiMode = ''fixed''.');
    end
    pr = mean(I(r(1):r(2), c(1):c(2)), 1);
    pr = movmean(double(pr), smoothPx);
end
