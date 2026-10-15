%% phone_spectrum.m
% Absorbance spectrum from smartphone photos of a dispersed white-light beam
% (prism or grating). Take all photos with the phone FIXED in place, with
% exposure, focus and white balance LOCKED, so only the sample changes.
%
% Photos needed (same phone position, same resolution, JPG/PNG):
%   reference  - beam with no sample (or with a solvent-only cuvette)
%   sample(s)  - beam with each coloured sample
%   calibration- beam with known spectral lines (laser pointers or a
%                fluorescent lamp) - optional; without it the x-axis is pixels
%   dark       - lamp blocked (optional; removes room light)
%
% You select the spectrum strip ONCE on the reference; the same crop is
% applied to every photo, so they stay aligned pixel for pixel.
% Base MATLAB only (no toolboxes needed).

clear; close all;

%% ---------------- User settings ----------------
refFile    = fullfile('photos','01_reference_white.jpg');   % beam without sample
sampleFile = fullfile('photos', {'02_sample1_a.jpg','04_sample2.jpg','05_sample3.jpg', ...
                                 '06_sample4.jpg','07_sample5.jpg'});
darkFile   = '';        % '' = no dark photo (00_control_no_lamp.jpg had room light, not usable)
calFile    = '';        % '' = no calibration yet -> x-axis in pixels
% NOTE: the 30 Sept test photos used AUTOMATIC exposure, so absorbance values
% are not quantitative. Retake in Pro mode (fixed ISO, shutter, white balance).
calNm      = [405 532 650];              % known wavelengths, in the order you will click them
fitOrder   = 1;                          % 1 for grating (near-linear), 2 for prism
dispersionAlongX = true;                 % false if the rainbow runs vertically in the photo
linearizeSRGB    = true;                 % undo JPEG gamma (approximate)
minRefFrac = 0.05;                       % ignore regions where reference < 5% of its maximum
smoothPx   = 5;                          % moving-average window in pixels (1 = none)

%% ---------------- Select the spectrum strip once ----------------
ref = loadImg(refFile, dispersionAlongX, linearizeSRGB);
figure('Name','Select spectrum strip');
image(min(ref ./ max(ref(:)), 1)); axis image;
title('Click two opposite corners of the spectrum strip');
[xc, yc] = ginput(2); close;
c = round(sort(xc)); r = round(sort(yc));
c = max(c,1); r = max(r,1);
roi  = @(I) I(r(1):r(2), c(1):c(2), :);
prof = @(I) movmean(mean(sum(roi(I),3),1), smoothPx);   % average across strip -> 1 x N

%% ---------------- Reference and dark ----------------
if ~isempty(darkFile)
    Idark = prof(loadImg(darkFile, dispersionAlongX, linearizeSRGB));
else
    Idark = 0;
end
Iref = prof(ref) - Idark;
px   = 1:numel(Iref);

%% ---------------- Wavelength calibration ----------------
if ~isempty(calFile)
    Ical = prof(loadImg(calFile, dispersionAlongX, linearizeSRGB)) - Idark;
    figure('Name','Calibration'); plot(px, Ical); xlabel('Pixel'); ylabel('Intensity');
    title(sprintf('Click the %d calibration peaks in the same order as calNm', numel(calNm)));
    [xp, ~] = ginput(numel(calNm)); close;
    pk = zeros(size(xp));
    for k = 1:numel(xp)                  % snap each click to the nearest local maximum
        w = max(1, round(xp(k))-10) : min(numel(Ical), round(xp(k))+10);
        [~, i] = max(Ical(w)); pk(k) = w(i);
    end
    p   = polyfit(pk, calNm(:), fitOrder);
    lam = polyval(p, px);
    fprintf('Calibration peaks at pixels %s\n', mat2str(pk', 4));
    fprintf('Residuals (nm): %s\n', mat2str((calNm(:) - polyval(p, pk))', 3));
    xl = 'Wavelength (nm)';
else
    lam = px; xl = 'Pixel';
end

%% ---------------- Samples: transmittance and absorbance ----------------
valid = Iref > minRefFrac * max(Iref);
out = table(lam(:), Iref(:), 'VariableNames', {'x', 'I_ref'});

figure('Name','Phone spectra');
ax1 = subplot(2,1,1); hold(ax1,'on');
plot(ax1, lam, Iref, 'k', 'LineWidth', 1.2, 'DisplayName', 'reference');
ax2 = subplot(2,1,2); hold(ax2,'on');

for s = 1:numel(sampleFile)
    Is = prof(loadImg(sampleFile{s}, dispersionAlongX, linearizeSRGB)) - Idark;
    T  = Is ./ Iref;
    A  = -log10(max(T, 1e-3));
    A(~valid) = NaN;
    [~, name] = fileparts(sampleFile{s});
    vn = matlab.lang.makeValidName(name);
    plot(ax1, lam, Is, 'DisplayName', name);
    plot(ax2, lam, A, 'LineWidth', 1.2, 'DisplayName', name);
    out.(['I_' vn]) = Is(:);
    out.(['A_' vn]) = A(:);
end

xlabel(ax1, xl); ylabel(ax1, 'Intensity (a.u.)'); title(ax1, 'Transmitted light'); legend(ax1, 'show');
xlabel(ax2, xl); ylabel(ax2, 'Absorbance');       title(ax2, 'A = -log_{10}(I_{sample} / I_{ref})'); legend(ax2, 'show');

if ~strcmp(xl, 'Pixel'), out.Properties.VariableNames{1} = 'wavelength_nm'; end
writetable(out, 'phone_spectra.csv');
fprintf('Saved phone_spectra.csv\n');

%% ---------------- Helper ----------------
function I = loadImg(f, alongX, lin)
    I = imread(f);
    try                                   % apply EXIF orientation (imread ignores it)
        info = imfinfo(f);
        if isfield(info, 'Orientation')
            switch info(1).Orientation
                case 3, I = rot90(I, 2);
                case 6, I = rot90(I, -1);
                case 8, I = rot90(I, 1);
            end
        end
    catch
    end
    if isa(I, 'uint16'), I = double(I) / 65535; else, I = double(I) / 255; end
    if size(I,3) == 1, I = repmat(I, 1, 1, 3); end
    if size(I,3) == 4, I = I(:,:,1:3); end
    if lin   % approximate inverse sRGB gamma so intensities are ~linear
        I = (I <= 0.04045) .* (I / 12.92) + (I > 0.04045) .* (((I + 0.055) / 1.055) .^ 2.4);
    end
    if ~alongX, I = permute(I, [2 1 3]); end
end
