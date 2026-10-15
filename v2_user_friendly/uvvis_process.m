function T = uvvis_process(files, varargin)
%UVVIS_PROCESS  Baseline-correct and normalise laboratory UV-Vis spectra.
%
%   uvvis_process                      choose CSV files in a dialog
%   uvvis_process('C:\data\uvvis')     all CSV files in a folder
%   uvvis_process({'a.csv','b.csv'})   a list of files
%   T = uvvis_process(..., 'Name', value)
%
%   Options (defaults in brackets)
%     'Range'          wavelength range kept, nm            [380 800]
%     'BaselineWindow' region where samples do not absorb   [750 800]
%     'LampArtefacts'  instrument lamp lines to smooth over [486 656]
%     'Names'          legend names (cell array)            file names
%     'Plot'           show figure                          true
%     'SaveAs'         output prefix ('' = do not save)     'UVVis_processed'
%
%   Steps: crop -> replace +/-2 nm around each lamp line by a local quadratic
%   fit (+/-10 nm) -> subtract mean absorbance in BaselineWindow -> normalise
%   to the maximum. All spectra are put on a common 1 nm grid.
%   Reads UTF-16 instrument exports directly.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));

p = inputParser;
addParameter(p, 'Range', [380 800]);
addParameter(p, 'BaselineWindow', [750 800]);
addParameter(p, 'LampArtefacts', [486 656]);
addParameter(p, 'Names', {});
addParameter(p, 'Plot', true);
addParameter(p, 'SaveAs', 'UVVis_processed');
parse(p, varargin{:});
o = p.Results;

% ---- which files
if nargin < 1 || isempty(files)
    [f, d] = uigetfile({'*.csv;*.CSV;*.txt', 'Spectra (CSV/TXT)'}, 'Choose UV-Vis spectra', 'MultiSelect', 'on');
    if isequal(f, 0), T = table(); return; end
    files = fullfile(d, cellstr(f));
else
    files = cellstr(files);
    if numel(files) == 1 && isfolder(files{1})
        L = [dir(fullfile(files{1}, '*.csv')); dir(fullfile(files{1}, '*.CSV'))];
        files = unique(fullfile({L.folder}, {L.name}));
        if isempty(files), error('No CSV files found in that folder.'); end
    end
end
nF = numel(files);
names = o.Names;
if isempty(names)
    names = cell(1, nF);
    for k = 1:nF, [~, names{k}] = fileparts(files{k}); end
end

% ---- process
wlg = (o.Range(1):o.Range(2))';
T = table(wlg, 'VariableNames', {'wavelength_nm'});
Aall = nan(numel(wlg), nF);
fprintf('\n%-25s %10s %8s %10s\n', 'Spectrum', 'lambda_max', 'A_max', 'baseline');
for k = 1:nF
    [wl, A] = psm_readSpectrumCSV(files{k});
    [wl, i] = sort(wl);  A = A(i);
    m = wl >= o.Range(1) - 15 & wl <= o.Range(2) + 15;
    wl = wl(m);  A = A(m);
    for c = o.LampArtefacts
        bad = abs(wl - c) <= 2;  fit = abs(wl - c) <= 10 & ~bad;
        if nnz(bad) > 0 && nnz(fit) >= 4
            pp = polyfit(wl(fit) - c, A(fit), 2);
            A(bad) = polyval(pp, wl(bad) - c);
        end
    end
    Ag = interp1(wl, A, wlg, 'linear', NaN);
    bw = wlg >= o.BaselineWindow(1) & wlg <= o.BaselineWindow(2);
    base = mean(Ag(bw), 'omitnan');
    if isnan(base), base = 0; end
    Ag = Ag - base;
    [Amax, i] = max(Ag);
    Aall(:, k) = Ag;
    vn = matlab.lang.makeValidName(names{k});
    T.([vn '_A']) = Ag;
    T.([vn '_Anorm']) = Ag / Amax;
    fprintf('%-25s %7d nm %8.3f %10.3f\n', names{k}, wlg(i), Amax, base);
end

% ---- plot
if o.Plot
    figure('Color', 'w', 'Name', 'UV-Vis spectra', 'Position', [100 100 1100 420]);
    ax1 = subplot(1, 2, 1);  hold(ax1, 'on');
    ax2 = subplot(1, 2, 2);  hold(ax2, 'on');
    for k = 1:nF
        plot(ax1, wlg, Aall(:, k), 'LineWidth', 1.8, 'DisplayName', names{k});
        plot(ax2, wlg, Aall(:, k) / max(Aall(:, k)), 'LineWidth', 1.8, 'DisplayName', names{k});
    end
    xlabel(ax1, 'Wavelength (nm)');  ylabel(ax1, 'Absorbance (baseline-corrected)');  box(ax1, 'off');
    xlabel(ax2, 'Wavelength (nm)');  ylabel(ax2, 'Normalised absorbance');            box(ax2, 'off');
    xlim(ax1, o.Range);  xlim(ax2, o.Range);
    legend(ax2, 'Box', 'off', 'Interpreter', 'none', 'Location', 'best');
    if ~isempty(o.SaveAs)
        exportgraphics(gcf, [o.SaveAs '.png'], 'Resolution', 300);
    end
end
if ~isempty(o.SaveAs)
    writetable(T, [o.SaveAs '.csv']);
    fprintf('Saved %s.csv%s in %s\n', o.SaveAs, ifelse(o.Plot, ' and .png', ''), pwd);
end
end

function s = ifelse(c, a, b)
if c, s = a; else, s = b; end
end
