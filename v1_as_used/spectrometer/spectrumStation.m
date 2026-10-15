function spectrumStation
% SPECTRUMSTATION  Live smartphone spectrometer for outreach events.
%
% The phone photographs the rainbow on the paper screen; the photos arrive in a
% folder on the laptop (cloud sync, USB, Wi-Fi transfer app ...). This app
% watches that folder and turns each new sample photo into an absorbance
% spectrum:  A = -log10( (I_sample - I_dark) / (I_ref - I_dark) ).
%
% SETUP (once, before visitors arrive)
%   1. Choose photo folder
%   2. Take a photo with the lamp blocked      -> "Latest photo = DARK" (optional)
%   3. Take a photo with solvent-only cuvette  -> "Latest photo = REFERENCE"
%   4. "Select spectrum strip"  (click two corners around the rainbow)
%   5. Photo of laser spots / pencil marks     -> "Calibrate" (click marks, type nm)
%   6. Tick "Auto-process new photos"
% TESTING WITHOUT A PHONE
%   Use "Load photo from file..." to pick any photo, then the buttons above
%   (reference / strip / "Process latest photo now").
% EVENT
%   Put a sample in, take a photo -> spectrum appears automatically.
%
% Keep phone position, exposure, focus and white balance FIXED throughout.
% Save photos as JPG/PNG (MATLAB cannot read HEIC).
% Base MATLAB only (R2020b or newer recommended). No toolboxes needed.

%% ---------------- State ----------------
S.folder = '';  S.lastFile = '';  S.lastTime = 0;
S.latest = [];  S.dark = [];  S.ref = [];
S.roi = [];                 % [row1 row2 col1 col2] in full-resolution pixels
S.p = [];                   % calibration polynomial (pixel index -> nm)
S.vertical = false;         % rainbow runs vertically in the photo?
S.minRefFrac = 0.05;        % ignore where reference < 5 % of its maximum
S.smoothPx = 7;             % moving-average window along the spectrum
S.k = 4;                    % display downsampling factor
S.results = struct('name', {}, 'x', {}, 'A', {}, 'Is', {});

%% ---------------- UI ----------------
fig = uifigure('Name', 'Phone spectrometer', 'Position', [60 60 1250 760]);
gl  = uigridlayout(fig, [1 2]);  gl.ColumnWidth = {270, '1x'};

pnl = uipanel(gl, 'Title', 'Controls');
cg  = uigridlayout(pnl, [15 1]);  cg.RowHeight = [repmat({34}, 1, 12), {'1x', 34, 34}];
uibutton(cg, 'Text', '1. Choose photo folder',            'ButtonPushedFcn', @chooseFolder);
uicheckbox(cg, 'Text', 'Rainbow runs vertically', 'Value', false, ...
    'ValueChangedFcn', @(s, ~) setVertical(s.Value));
uibutton(cg, 'Text', '2. Latest photo = DARK (optional)',  'ButtonPushedFcn', @setDark);
uibutton(cg, 'Text', '3. Latest photo = REFERENCE',        'ButtonPushedFcn', @setRef);
uibutton(cg, 'Text', '4. Select spectrum strip',           'ButtonPushedFcn', @selectROI);
uibutton(cg, 'Text', '5. Calibrate with latest photo',     'ButtonPushedFcn', @calibrate);
cbAuto = uicheckbox(cg, 'Text', '6. Auto-process new photos', 'Value', false);
uibutton(cg, 'Text', 'Process latest photo now', 'ButtonPushedFcn', @(~, ~) processLatest());
uibutton(cg, 'Text', 'Clear spectra',            'ButtonPushedFcn', @clearPlots);
uibutton(cg, 'Text', 'Save spectra (CSV + PNG)', 'ButtonPushedFcn', @saveAll);
uibutton(cg, 'Text', 'Load photo from file...', 'ButtonPushedFcn', @loadFromFile);  uilabel(cg, 'Text', '');
lblStatus = uilabel(cg, 'Text', 'Choose the folder where phone photos arrive.', 'WordWrap', 'on');
lblDark = uilabel(cg, 'Text', 'Dark: none');
lblRef  = uilabel(cg, 'Text', 'Reference: none');

rg = uigridlayout(gl, [2 2]);  rg.RowHeight = {'1x', '1.2x'};
axImg = uiaxes(rg);  axImg.Layout.Row = 1; axImg.Layout.Column = 1;
title(axImg, 'Latest photo');  axImg.XTick = []; axImg.YTick = [];
axInt = uiaxes(rg);  axInt.Layout.Row = 1; axInt.Layout.Column = 2;
title(axInt, 'Light on the screen'); ylabel(axInt, 'Intensity (a.u.)'); xlabel(axInt, 'Pixel');
axA = uiaxes(rg);    axA.Layout.Row = 2; axA.Layout.Column = [1 2];
title(axA, 'Absorbance spectrum'); ylabel(axA, 'Absorbance'); xlabel(axA, 'Pixel');
hold(axA, 'on'); grid(axA, 'on');

tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~) poll());
fig.CloseRequestFcn = @onClose;

%% ---------------- Callbacks ----------------
    function chooseFolder(~, ~)
        d = uigetdir(pwd, 'Folder where phone photos arrive');
        figure(fig);
        if isequal(d, 0), return; end
        S.folder = d;
        f = newestFile();
        if ~isempty(f)
            S.lastFile = f.name; S.lastTime = f.datenum;
            loadLatest(f.name);
        end
        if strcmp(tmr.Running, 'off'), start(tmr); end
        status(['Watching: ' d]);
    end

    function loadFromFile(~, ~)
        % Pick any photo by hand (testing, or if folder syncing fails at the event)
        if isempty(S.folder), startDir = pwd; else, startDir = S.folder; end
        [f, d] = uigetfile({'*.jpg;*.jpeg;*.png;*.tif;*.tiff', 'Images'}, 'Choose a photo', startDir);
        figure(fig);
        if isequal(f, 0), return; end
        S.latest = loadImg(fullfile(d, f));
        S.latest.name = f;
        showImage(S.latest);
        status(['Loaded ' f]);
    end

    function setVertical(v)
        S.vertical = v;
        status('Orientation changed - select the strip and calibrate again.');
        S.roi = []; S.p = [];
    end

    function setDark(~, ~)
        if isempty(S.latest), uialert(fig, 'No photo loaded yet.', 'Dark'); return; end
        S.dark = S.latest;  lblDark.Text = ['Dark: ' S.dark.name];
        status('Dark photo stored.');
    end

    function setRef(~, ~)
        if isempty(S.latest), uialert(fig, 'No photo loaded yet.', 'Reference'); return; end
        S.ref = S.latest;  lblRef.Text = ['Reference: ' S.ref.name];
        status('Reference stored. Now select the spectrum strip (step 4).');
        if ~isempty(S.roi), checkSaturation(); end
    end

    function selectROI(~, ~)
        if isempty(S.ref), uialert(fig, 'Store a reference photo first (step 3).', 'Strip'); return; end
        h = figure('Name', 'Select spectrum strip', 'NumberTitle', 'off');
        image(S.ref.thumb); axis image; axis off;
        title('Click two opposite corners of a strip along the middle of the rainbow');
        [x, y] = ginput(2);  close(h);  figure(fig);
        if numel(x) < 2, return; end
        [H, W] = size(S.ref.I);
        r = min(max(round(sort(y) * S.k), 1), H);
        c = min(max(round(sort(x) * S.k), 1), W);
        if diff(r) < 2 || diff(c) < 2, uialert(fig, 'Strip too small.', 'Strip'); return; end
        S.roi = [r(1) r(2) c(1) c(2)];  S.p = [];
        showImage(S.latest);  checkSaturation();  plotReference();
        status('Strip selected. Now calibrate (step 5), or skip to use a pixel axis.');
    end

    function calibrate(~, ~)
        if isempty(S.roi), uialert(fig, 'Select the spectrum strip first (step 4).', 'Calibrate'); return; end
        if isempty(S.latest), return; end
        h = figure('Name', 'Calibration', 'NumberTitle', 'off');
        image(S.latest.thumb); axis image; axis off; hold on;
        rectangle('Position', roiThumbPos(), 'EdgeColor', 'w', 'LineStyle', '--');
        title({'Click each laser spot / pencil mark (left to right), then press ENTER'});
        [x, y] = ginput();  close(h);  figure(fig);
        if numel(x) < 2, uialert(fig, 'Click at least two marks.', 'Calibrate'); return; end
        if S.vertical, pos = y * S.k - S.roi(1) + 1; else, pos = x * S.k - S.roi(3) + 1; end
        answ = inputdlg(sprintf('Wavelengths (nm) of the %d marks, in the same order, separated by commas:', numel(pos)), ...
                        'Calibration', 1, {''});
        figure(fig);
        if isempty(answ), return; end
        lam = str2num(answ{1}); %#ok<ST2NM>
        if numel(lam) ~= numel(pos), uialert(fig, 'Number of wavelengths does not match number of clicks.', 'Calibrate'); return; end
        snap = uiconfirm(fig, 'Snap clicks to the nearest bright peak? (Yes for laser spots, No for pencil marks)', ...
                         'Calibration', 'Options', {'Yes', 'No'}, 'DefaultOption', 2);
        if strcmp(snap, 'Yes')
            pr = profileOf(S.latest);
            for q = 1:numel(pos)
                w = max(1, round(pos(q)) - 15) : min(numel(pr), round(pos(q)) + 15);
                [~, i] = max(pr(w));  pos(q) = w(i);
            end
        end
        if numel(pos) >= 3
            typ = uiconfirm(fig, 'Dispersing element?', 'Calibration', ...
                            'Options', {'Grating (linear fit)', 'Prism (quadratic fit)'}, 'DefaultOption', 1);
            order = 1 + strcmp(typ, 'Prism (quadratic fit)');
        else
            order = 1;
        end
        S.p = polyfit(pos(:), lam(:), order);
        res = lam(:) - polyval(S.p, pos(:));
        if numel(pos) > order + 1
            status(sprintf('Calibrated (order %d). Residuals: %s nm', order, mat2str(round(res', 1))));
        else
            status(sprintf('Calibrated (order %d). Exact fit - add more marks to check accuracy.', order));
        end
        clearPlots(); plotReference();
    end

    function processLatest()
        if isempty(S.ref) || isempty(S.roi)
            status('Set a reference (step 3) and select the strip (step 4) first.'); return;
        end
        if isempty(S.latest), return; end
        Iref = profileOf(S.ref) - darkProfile();
        Is   = profileOf(S.latest) - darkProfile();
        T = Is ./ Iref;
        A = -log10(max(T, 1e-3));
        A(Iref < S.minRefFrac * max(Iref)) = NaN;
        x = xAxis(numel(A));
        [~, nm] = fileparts(S.latest.name);
        plot(axA, x, A, 'LineWidth', 1.6, 'DisplayName', nm);
        [Amax, i] = max(A);
        if ~isnan(Amax)
            text(axA, x(i), Amax, sprintf('  %.0f', x(i)), 'FontSize', 10);
        end
        legend(axA, 'Interpreter', 'none', 'Location', 'best');
        plotReference(); hold(axInt, 'on');
        plot(axInt, x, Is, 'DisplayName', nm); hold(axInt, 'off');
        legend(axInt, 'Interpreter', 'none');
        S.results(end+1) = struct('name', nm, 'x', x(:), 'A', A(:), 'Is', Is(:));
        if isempty(S.p)
            status(sprintf('%s processed (pixel axis - not calibrated).', nm));
        else
            status(sprintf('%s processed. Peak at %.0f nm.', nm, x(i)));
        end
    end

    function clearPlots(~, ~)
        cla(axA); legend(axA, 'off'); S.results = S.results([]);
        if isempty(S.p), xlabel(axA, 'Pixel'); xlabel(axInt, 'Pixel');
        else, xlabel(axA, 'Wavelength (nm)'); xlabel(axInt, 'Wavelength (nm)'); end
    end

    function saveAll(~, ~)
        if isempty(S.results), uialert(fig, 'Nothing to save yet.', 'Save'); return; end
        [f, d] = uiputfile('spectra.csv', 'Save spectra');  figure(fig);
        if isequal(f, 0), return; end
        T = table();
        for q = 1:numel(S.results)
            R = S.results(q);
            T = [T; table(repmat(string(R.name), numel(R.x), 1), R.x, R.A, R.Is, ...
                 'VariableNames', {'sample', 'x', 'absorbance', 'intensity'})]; %#ok<AGROW>
        end
        writetable(T, fullfile(d, f));
        [~, b] = fileparts(f);
        exportgraphics(axA, fullfile(d, [b '_absorbance.png']), 'Resolution', 300);
        status(['Saved ' fullfile(d, f)]);
    end

    function onClose(~, ~)
        try, stop(tmr); delete(tmr); catch, end
        delete(fig);
    end

%% ---------------- Folder watching ----------------
    function poll()
        try
            if isempty(S.folder), return; end
            f = newestFile();
            if isempty(f) || (strcmp(f.name, S.lastFile) && f.datenum <= S.lastTime), return; end
            pause(0.7);                                   % let the file finish copying
            f2 = dir(fullfile(S.folder, f.name));
            if isempty(f2) || f2.bytes ~= f.bytes, return; end
            S.lastFile = f.name;  S.lastTime = f.datenum;
            loadLatest(f.name);
            if cbAuto.Value, processLatest(); end
        catch err
            status(['Error: ' err.message]);
        end
    end

    function f = newestFile()
        L = dir(S.folder);  L = L(~[L.isdir]);  f = [];
        if isempty(L), return; end
        [~, ~, ext] = cellfun(@fileparts, {L.name}, 'UniformOutput', false);
        L = L(ismember(lower(ext), {'.jpg', '.jpeg', '.png', '.tif', '.tiff'}));
        if isempty(L), return; end
        [~, i] = max([L.datenum]);  f = L(i);
    end

    function loadLatest(name)
        S.latest = loadImg(fullfile(S.folder, name));
        S.latest.name = name;
        showImage(S.latest);
        status(['Loaded ' name]);
    end

%% ---------------- Helpers ----------------
    function P = loadImg(file)
        raw = imread(file);
        raw = applyOrientation(raw, file);             % phone photos are stored rotated
        if size(raw, 3) == 1, raw = repmat(raw, 1, 1, 3); end
        raw = raw(:, :, 1:3);
        if isa(raw, 'uint16'), sc = 65535; else, sc = 255; end
        P.sat = any(raw >= 0.98 * sc, 3);               % saturated pixels
        I = single(raw) / sc;
        I = (I <= 0.04045) .* (I / 12.92) + (I > 0.04045) .* (((I + 0.055) / 1.055) .^ 2.4); % undo sRGB gamma
        P.I = sum(I, 3);                                 % linear intensity, all colours
        th = raw(1:S.k:end, 1:S.k:end, :);
        if ~isa(th, 'uint8'), th = uint8(double(th) / sc * 255); end
        P.thumb = th;
    end

    function I = applyOrientation(I, file)
        % Apply the EXIF orientation flag (imread ignores it)
        try
            info = imfinfo(file);
            if isfield(info, 'Orientation')
                switch info(1).Orientation
                    case 3, I = rot90(I, 2);
                    case 6, I = rot90(I, -1);
                    case 8, I = rot90(I, 1);
                end
            end
        catch
        end
    end

    function pr = profileOf(P)
        r = S.roi;  sub = P.I(r(1):r(2), r(3):r(4));
        if S.vertical, pr = mean(sub, 2)'; else, pr = mean(sub, 1); end
        pr = movmean(double(pr), S.smoothPx);
    end

    function d = darkProfile()
        if isempty(S.dark), d = 0; else, d = profileOf(S.dark); end
    end

    function x = xAxis(n)
        if isempty(S.p), x = 1:n; else, x = polyval(S.p, 1:n); end
    end

    function checkSaturation()
        if isempty(S.ref) || isempty(S.roi), return; end
        r = S.roi;  frac = mean(S.ref.sat(r(1):r(2), r(3):r(4)), 'all');
        if frac > 0.01
            uialert(fig, sprintf(['%.0f %% of the reference strip is saturated. ' ...
                'Lower the phone exposure and retake dark + reference.'], 100 * frac), ...
                'Overexposed', 'Icon', 'warning');
        end
    end

    function plotReference()
        if isempty(S.ref) || isempty(S.roi), return; end
        Iref = profileOf(S.ref) - darkProfile();
        x = xAxis(numel(Iref));
        cla(axInt); plot(axInt, x, Iref, 'k', 'LineWidth', 1.4, 'DisplayName', 'reference');
        legend(axInt, 'Interpreter', 'none');
        if isempty(S.p), xlabel(axInt, 'Pixel'); xlabel(axA, 'Pixel');
        else, xlabel(axInt, 'Wavelength (nm)'); xlabel(axA, 'Wavelength (nm)'); end
    end

    function showImage(P)
        if isempty(P), return; end
        cla(axImg); image(axImg, P.thumb); axis(axImg, 'image');
        axImg.XTick = []; axImg.YTick = []; title(axImg, P.name, 'Interpreter', 'none');
        if ~isempty(S.roi)
            rectangle(axImg, 'Position', roiThumbPos(), 'EdgeColor', 'w', 'LineWidth', 1.5);
        end
    end

    function pos = roiThumbPos()
        r = S.roi / S.k;
        pos = [r(3), r(1), r(4) - r(3), r(2) - r(1)];
    end

    function status(msg)
        lblStatus.Text = msg;  drawnow limitrate;
    end
end
