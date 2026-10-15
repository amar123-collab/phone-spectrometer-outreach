%% overlay_phone_uv.m - overlay smartphone spectra on laboratory UV-Vis spectra
% Needs: phone_spectra.csv   (from run_spectra.m)
%        UVVis_processed.csv (from process_uv.m; columns wavelength_nm, S1_Anorm ...)
%
% Wavelength axis for the phone: APPROXIMATE, from a prism (Cauchy-type) model
%   pixel = a + b / lambda^2
% fitted to the phone peak positions vs laboratory lambda_max of samples 1,3,4,5.
% Sample 2 is excluded (its peak lies at the edge of the usable range) and so
% serves as an independent check. Replace with laser calibration when available.

clear; close all;
ph = readtable('phone_spectra.csv');
uv = readtable('UVVis_processed.csv');

names   = {'Sample 1 (blue)','Sample 2 (yellow)','Sample 3 (dark blue)','Sample 4 (violet)','Sample 5 (pink)'};
cols    = [0.17 0.31 0.84; 0.83 0.66 0; 0.04 0.16 0.42; 0.48 0.18 0.82; 0.91 0.25 0.54];
labLmax = [588 454 655 570 544];     % nm, from process_uv.m
useFit  = [1 3 4 5];                 % samples used to build the wavelength axis

% phone peak positions
pk = zeros(1,5);
for k = 1:5
    [~, i] = max(ph.(sprintf('A_S%d', k)));  pk(k) = ph.pixel(i);
end

% fit pixel = a + b/lambda^2   (linear least squares in [1, 1/lambda^2])
X = [ones(numel(useFit),1), 1 ./ labLmax(useFit)'.^2];
c = X \ pk(useFit)';                 % c(1) = a, c(2) = b
px2nm = @(x) sqrt(c(2) ./ (x - c(1)));
lam = px2nm(ph.pixel);
fprintf('Fit residuals (nm): %s\n', mat2str(round(px2nm(pk(useFit)) - labLmax(useFit), 1)));

figure('Color','w','Position',[80 80 1200 700]);
tiledlayout(2, 3, 'TileSpacing','compact');
for k = 1:5
    nexttile; hold on;
    plot(uv.wavelength_nm, uv.(sprintf('S%d_Anorm', k)), 'Color', [0.25 0.25 0.25], ...
         'LineWidth', 2, 'DisplayName', 'Laboratory UV-Vis');
    A = ph.(sprintf('A_S%d', k));  An = A / max(A, [], 'omitnan');
    plot(lam, An, '--', 'Color', cols(k,:), 'LineWidth', 2.2, 'DisplayName', 'Smartphone photo');
    xlim([420 720]); ylim([-0.15 1.15]); box off; title(names{k}, 'FontWeight','normal');
    xlabel('Wavelength (nm)'); ylabel('Normalised absorbance');
    if k == 1, legend('Box','off','Location','northwest'); end
end
nexttile; hold on;
xx = linspace(min(ph.pixel(~isnan(ph.A_S1))), max(ph.pixel(~isnan(ph.A_S1))), 200);
plot(xx, px2nm(xx), 'k-', 'LineWidth', 1.5, 'DisplayName', 'prism model');
for k = useFit
    plot(pk(k), labLmax(k), 'o', 'MarkerFaceColor', cols(k,:), 'MarkerEdgeColor', cols(k,:), ...
         'MarkerSize', 8, 'HandleVisibility', 'off');
end
xlabel('Position along rainbow (pixels)'); ylabel('Wavelength (nm)'); box off;
title('Approximate wavelength axis', 'FontWeight','normal'); legend('Box','off','Location','northwest');

exportgraphics(gcf, 'Fig_phone_vs_UVVis_overlay.png', 'Resolution', 300);
T = table(ph.pixel, lam, 'VariableNames', {'pixel','wavelength_nm_approx'});
writetable(T, 'phone_wavelength_axis.csv');
