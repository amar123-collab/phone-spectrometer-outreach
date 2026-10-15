%% process_uv.m - baseline correction and normalisation of UV-Vis spectra
% Run from this folder:  >> process_uv
% Input : sample1.csv ... sample5.csv (UTF-8 copies of the instrument exports;
%         the untouched originals are in raw_instrument_files/)
% Steps : (1) crop 380-800 nm (plastic cuvettes);
%         (2) replace +/-2 nm around the D2-lamp emission lines (486, 656 nm)
%             by a local quadratic fit to the neighbouring +/-10 nm;
%         (3) subtract the mean absorbance at 750-800 nm (baseline offset);
%         (4) normalise to the maximum.
% Output: UVVis_processed.csv, UVVis_processed.png

files = {'sample1.csv','sample2.csv','sample3.csv','sample4.csv','sample5.csv'};
names = {'Sample 1 (blue)','Sample 2 (yellow)','Sample 3 (dark blue)','Sample 4 (violet)','Sample 5 (pink)'};
cols  = [0.17 0.31 0.84; 0.83 0.66 0; 0.04 0.16 0.42; 0.48 0.18 0.82; 0.91 0.25 0.54];
artefacts = [486 656];

out = table();
figure('Color','w','Position',[100 100 1100 420]);
ax1 = subplot(1,2,1); hold(ax1,'on'); ax2 = subplot(1,2,2); hold(ax2,'on');
for k = 1:numel(files)
    T  = readmatrix(files{k});                      % header line is skipped automatically
    wl = T(:,1);  A = T(:,2);
    m  = wl >= 380 & wl <= 800;  wl = wl(m);  A = A(m);
    for c = artefacts                               % repair lamp-line artefacts
        bad = abs(wl - c) <= 2;  fit = abs(wl - c) <= 10 & ~bad;
        p = polyfit(wl(fit) - c, A(fit), 2);
        A(bad) = polyval(p, wl(bad) - c);
    end
    base = mean(A(wl >= 750 & wl <= 800));
    A = A - base;                                   % baseline offset
    [Amax, i] = max(A);  An = A / Amax;             % normalise
    fprintf('%-22s lambda_max = %d nm   A_max = %.3f   baseline removed = %.3f\n', ...
            names{k}, wl(i), Amax, base);
    plot(ax1, wl, A,  'Color', cols(k,:), 'LineWidth', 1.8, 'DisplayName', names{k});
    plot(ax2, wl, An, 'Color', cols(k,:), 'LineWidth', 1.8, 'DisplayName', names{k});
    if k == 1, out.wavelength_nm = wl; end
    out.(sprintf('S%d_Acorr', k)) = A;
    out.(sprintf('S%d_Anorm', k)) = An;
end
xlabel(ax1,'Wavelength (nm)'); ylabel(ax1,'Absorbance (baseline-corrected)'); xlim(ax1,[380 800]); box(ax1,'off');
xlabel(ax2,'Wavelength (nm)'); ylabel(ax2,'Normalised absorbance');           xlim(ax2,[380 800]); box(ax2,'off');
legend(ax2, 'Location', 'east', 'Box', 'off');
writetable(out, 'UVVis_processed.csv');
exportgraphics(gcf, 'UVVis_processed.png', 'Resolution', 300);
disp('Saved UVVis_processed.csv and UVVis_processed.png');
