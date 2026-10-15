function PhoneSpectrometer
%PHONESPECTROMETER  Smartphone spectrometer - point-and-click app.
%
%   Type  PhoneSpectrometer  in MATLAB. Work down the numbered steps on the
%   left; every button explains itself in the status line at the bottom.
%   See HOW_TO_USE.txt for the full guide. Base MATLAB R2020b or newer,
%   no toolboxes.
%
%   1. Photos      choose the folder where the phone photos are (live mode
%                  picks up new photos as they arrive)
%   2. Reference   pick the white-light photo (and optionally a dark photo)
%   3. Strip       the rainbow is found automatically; redraw it if needed
%   4. Wavelength  optional: calibrate with a photo of laser spots
%   5. Measure     pick sample photos -> absorbance spectra appear
%   6. Save        CSV + PNG + a log of all settings

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));
appVersion = '2.0';

%% ---------------- state ----------------
S.folder = '';  S.seen = {};
S.ref = [];  S.dark = [];  S.strip = [];
S.Iref = [];  S.Idark = 0;
S.cal = psm_calibration('none');
S.results = struct('name', {}, 'Is', {}, 'Araw', {}, 'notes', {});
S.lab = struct('name', {}, 'wl', {}, 'A', {});
S.opt = struct('align', true, 'minRef', 30, 'smooth', 5, 'offset', 'none', ...
               'normalise', false, 'stripFrac', 0.4, 'dispersion', 'prism');

%% ---------------- window ----------------
fig = uifigure('Name', ['Phone spectrometer ' appVersion], 'Position', [40 40 1360 800]);
main = uigridlayout(fig, [2 2]);
main.ColumnWidth = {340, '1x'};  main.RowHeight = {'1x', 30};

L = uigridlayout(main, [27 2]);
L.Layout.Row = 1;  L.Layout.Column = 1;
L.Scrollable = 'on';  L.RowSpacing = 4;  L.ColumnWidth = {'1x', '1x'};
L.RowHeight = [{22, 30, 170, 24}, {22, 30, 34}, {22, 30, 24}, {22, 26, 30, 30, 40}, ...
               {22, 30, 24, 26, 26, 24}, {22, 30, 30, 30, 30, 30}];   % 27 rows, in the order built below
r = 0;
addHead('1. Photos');
addBtn('Choose photo folder...', @chooseFolder);
r = r + 1;
lb = uilistbox(L, 'Items', {}, 'Multiselect', 'on', 'ValueChangedFcn', @(~, ~) safe(@previewSelected));
lb.Layout.Row = r;  lb.Layout.Column = [1 2];
cbWatch = addChk('Watch folder for new photos (live)', false, @setWatch);

addHead('2. Reference and dark');
addBtn('Selected = REFERENCE', @setReference, 1);
addBtn('Selected = DARK', @setDark, 2);
lblRef = addInfo('Reference: none.  Dark: none (optional).');

addHead('3. Rainbow strip');
addBtn('Find automatically', @autoStrip, 1);
addBtn('Draw by hand...', @drawStrip, 2);
addChk('Follow small phone movements (align on blue)', true, @(v) setOpt('align', v));

addHead('4. Wavelength axis (optional)');
r = r + 1;
ddDisp = uidropdown(L, 'Items', {'Prism (curved fit)', 'Grating (straight line)'}, ...
    'ValueChangedFcn', @(s, ~) setOpt('dispersion', lower(strtok(s.Value))));
ddDisp.Layout.Row = r;  ddDisp.Layout.Column = [1 2];
addBtn('Calibrate: selected laser photo', @calibrateLaser);
addBtn('Estimate from known peaks...', @calibrateModel, 1);
addBtn('Remove calibration', @removeCal, 2);
lblCal = addInfo(S.cal.info);

addHead('5. Measure');
addBtn('Measure selected photo(s)', @measureSelected);
cbAuto = addChk('Measure new photos automatically (live)', false, @(v) []);
r = r + 1;
ddOff = uidropdown(L, 'Items', {'No offset correction (fixed exposure)', 'Auto offset (auto-exposure photos)'}, ...
    'ValueChangedFcn', @(s, ~) safe(@() setOffset(s.Value)));
ddOff.Layout.Row = r;  ddOff.Layout.Column = [1 2];
r = r + 1;
l = uilabel(L, 'Text', 'Ignore dim ends below (% of ref.)');  l.Layout.Row = r;  l.Layout.Column = 1;
efMin = uieditfield(L, 'numeric', 'Value', S.opt.minRef, 'Limits', [0 95], ...
    'ValueChangedFcn', @(s, ~) safe(@() setOpt('minRef', s.Value)));
efMin.Layout.Row = r;  efMin.Layout.Column = 2;
addChk('Normalise curves to peak = 1', false, @(v) setOpt('normalise', v));

addHead('6. Compare and save');
addBtn('Add lab spectrum (CSV)...', @addLab, 1);
addBtn('Clear lab spectra', @clearLab, 2);
addInfo('Lab spectra are shown only when the axis is in nm.');
addBtn('Save results...', @saveResults, 1);
addBtn('Clear results', @clearResults, 2);
addBtn('Save settings...', @saveSettings, 1);
addBtn('Load settings...', @loadSettings, 2);
addBtn('How to use', @showHelp);

R = uigridlayout(main, [2 2]);
R.Layout.Row = 1;  R.Layout.Column = 2;
R.ColumnWidth = {'1.3x', '1x'};  R.RowHeight = {'1x', '1.3x'};
axImg = uiaxes(R);  axImg.Layout.Row = 1;  axImg.Layout.Column = 1;
title(axImg, 'Photo');  axImg.XTick = [];  axImg.YTick = [];
axInt = uiaxes(R);  axInt.Layout.Row = 1;  axInt.Layout.Column = 2;
title(axInt, 'Light along the rainbow');  ylabel(axInt, 'Intensity (a.u.)');
axA = uiaxes(R);  axA.Layout.Row = 2;  axA.Layout.Column = 1;
title(axA, 'Absorbance');  ylabel(axA, 'Absorbance');  grid(axA, 'on');
tbl = uitable(R, 'ColumnName', {'Sample', 'Peak', 'A max', 'Notes'}, ...
    'ColumnWidth', {140, 70, 60, 'auto'}, 'RowName', {});
tbl.Layout.Row = 2;  tbl.Layout.Column = 2;

lblStatus = uilabel(main, 'Text', 'Start with step 1: choose the folder that holds the phone photos.', ...
    'FontWeight', 'bold');
lblStatus.Layout.Row = 2;  lblStatus.Layout.Column = [1 2];

tmr = timer('ExecutionMode', 'fixedSpacing', 'Period', 1.5, 'BusyMode', 'drop', ...
            'TimerFcn', @(~, ~) poll());
fig.CloseRequestFcn = @onClose;
updateLabels();

%% ================= callbacks: photos =================
    function chooseFolder()
        d = uigetdir(pwd, 'Folder with the phone photos');
        figure(fig);
        if isequal(d, 0), return; end
        S.folder = d;
        S.seen = listImages();
        refreshList();
        status(sprintf('%d photos found. Step 2: select the white-light photo and press "Selected = REFERENCE".', numel(S.seen)));
    end

    function names = listImages()
        names = {};
        if isempty(S.folder), return; end
        D = dir(S.folder);  D = D(~[D.isdir]);
        if isempty(D), return; end
        [~, ~, ext] = cellfun(@fileparts, {D.name}, 'UniformOutput', false);
        D = D(ismember(lower(ext), {'.jpg', '.jpeg', '.png', '.tif', '.tiff'}));
        [~, o] = sort([D.datenum]);
        names = {D(o).name};
    end

    function refreshList()
        names = listImages();
        labels = names;
        for i = 1:numel(names)
            tag = '';
            if ~isempty(S.ref)  && strcmp(names{i}, S.ref.name),  tag = '   [REFERENCE]'; end
            if ~isempty(S.dark) && strcmp(names{i}, S.dark.name), tag = '   [DARK]'; end
            if any(strcmp(names{i}, {S.results.name})),          tag = '   [measured]'; end
            labels{i} = [names{i} tag];
        end
        keep = lb.Value;
        lb.Items = labels;  lb.ItemsData = names;
        if ~isempty(keep), lb.Value = intersect(keep, names, 'stable'); end
    end

    function n = selected()
        n = lb.Value;
        if ischar(n), n = {n}; end
        if isempty(n), error('Select a photo in the list first (step 1).'); end
    end

    function previewSelected()
        n = lb.Value;  if ischar(n), n = {n}; end
        if isempty(n), return; end
        P = psm_loadPhoto(fullfile(S.folder, n{1}), 'preview');
        showPhoto(P, [0 0]);
    end

    function setWatch(v)
        if v && isempty(S.folder), cbWatch.Value = false; error('Choose a photo folder first.'); end
        if v && strcmp(tmr.Running, 'off'), start(tmr); end
        if ~v && strcmp(tmr.Running, 'on'),  stop(tmr);  end
        if v, status('Watching the folder: new photos appear in the list automatically.'); end
    end

    function poll()
        try
            names = listImages();
            new = setdiff(names, S.seen, 'stable');
            if isempty(new), return; end
            pause(0.8);                                     % let the copy finish
            S.seen = names;
            refreshList();
            status(sprintf('New photo: %s', new{end}));
            if cbAuto.Value && ~isempty(S.ref) && ~isempty(S.strip)
                measure(new);
            end
        catch err
            status(['Live mode: ' err.message], true);
        end
    end

%% ================= callbacks: reference, dark, strip =================
    function setReference()
        n = selected();
        S.ref = psm_loadPhoto(fullfile(S.folder, n{1}));
        S.results = S.results([]);
        autoStrip();
        status(['Reference set. Check that the white box sits on the rainbow, then step 5 ', ...
                '(or step 4 to calibrate wavelengths).']);
    end

    function setDark()
        n = selected();
        if isempty(S.ref), error('Set the reference first (step 2).'); end
        D = psm_loadPhoto(fullfile(S.folder, n{1}));
        if D.medianI > 2 * S.ref.medianI
            uialert(fig, ['This "dark" photo is brighter than the background of the reference. ', ...
                'Was the room light on, or were camera settings different? It was not used.'], 'Dark photo', 'Icon', 'warning');
            return;
        end
        S.dark = D;
        updateReference();
        status('Dark photo set and subtracted from all measurements.');
    end

    function autoStrip()
        if isempty(S.ref), error('Set the reference first (step 2).'); end
        S.strip = psm_findStrip(S.ref, S.opt.stripFrac);
        updateReference();
    end

    function drawStrip()
        if isempty(S.ref), error('Set the reference first (step 2).'); end
        h = figure('Name', 'Draw the strip', 'NumberTitle', 'off');
        image(S.ref.thumb);  axis image off;
        title({'Click two opposite corners of a thin box', 'along the middle of the rainbow'});
        [x, y] = ginput(2);  close(h);  figure(fig);
        if numel(x) < 2, return; end
        k = S.ref.thumbStep;
        rr = sort(round(y * k));  cc = sort(round(x * k));
        rr = min(max(rr, 1), size(S.ref.I, 1));  cc = min(max(cc, 1), size(S.ref.I, 2));
        if diff(rr) < 2 || diff(cc) < 2, error('The box is too small - try again.'); end
        S.strip.roi = [rr(:)' cc(:)'];
        S.strip.vertical = diff(rr) > diff(cc);
        S.strip.reverse = psm_isReversed(S.ref, S.strip.vertical);
        S.results = S.results([]);
        updateReference();
        status('Strip drawn by hand. Earlier results were cleared - measure again.');
    end

    function updateReference()
        Iraw = psm_profile(S.ref, S.strip, [0 0], S.opt.smooth);
        S.Idark = 0;
        if ~isempty(S.dark)
            S.Idark = psm_profile(S.dark, S.strip, psm_shift(S.dark, S.ref, S.opt.align), S.opt.smooth);
        end
        S.Iref = Iraw - S.Idark;
        r0 = S.strip.roi;
        satFrac = mean(S.ref.sat(r0(1):r0(2), r0(3):r0(4)), 'all');
        if satFrac > 0.01
            uialert(fig, sprintf(['%.0f %% of the rainbow is overexposed (pure white) in the reference. ', ...
                'Lower the exposure and retake reference and samples.'], 100 * satFrac), 'Overexposed', 'Icon', 'warning');
        end
        showPhoto(S.ref, [0 0]);
        refreshList();  updateLabels();  redraw();
    end

%% ================= callbacks: calibration =================
    function calibrateLaser()
        if isempty(S.strip), error('Set the reference first (step 2).'); end
        n = selected();
        P = psm_loadPhoto(fullfile(S.folder, n{1}));
        pr = psm_profile(P, S.strip, psm_shift(P, S.ref, false), S.opt.smooth);
        a = inputdlg({sprintf(['Wavelengths of the laser spots / lamp lines in %s (nm), separated by commas.\n', ...
            'Example: 405, 532, 650'], P.name)}, 'Calibration', 1, {'405, 532, 650'});
        figure(fig);
        if isempty(a), return; end
        nm = sort(str2num(a{1})); %#ok<ST2NM>
        if numel(nm) < 2, error('Give at least two wavelengths.'); end
        pk = psm_findPeaks(pr, numel(nm));
        if numel(pk) < numel(nm)
            error('Found only %d bright spots along the strip, but %d wavelengths were given.', numel(pk), numel(nm));
        end
        order = 1 + (strcmp(S.opt.dispersion, 'prism') && numel(nm) >= 3);
        S.cal = psm_calibration('laser', pk, nm, order);
        figure('Name', 'Calibration check', 'NumberTitle', 'off', 'Color', 'w');
        plot(pr, 'k');  hold on;
        plot(pk, pr(pk), 'ro', 'MarkerFaceColor', 'r');
        text(pk, pr(pk), compose('  %g nm', nm), 'VerticalAlignment', 'bottom');
        xlabel('Position along strip (px, blue \rightarrow red)');  ylabel('Intensity');
        title('Detected calibration lines - check they are the right spots');
        figure(fig);
        updateLabels();  redraw();
        status(S.cal.info);
    end

    function calibrateModel()
        if numel(S.results) < 3, error('Measure at least three samples first.'); end
        prompts = cellfun(@(s) sprintf('Known lambda_max of %s (nm, blank = skip)', s), {S.results.name}, 'UniformOutput', false);
        a = inputdlg(prompts, 'Estimate wavelength axis', 1);
        figure(fig);
        if isempty(a), return; end
        nm = str2double(a);  use = find(isfinite(nm));
        if numel(use) < 3, error('Give at least three known peak wavelengths.'); end
        pk = zeros(1, numel(use));
        for i = 1:numel(use)
            [~, pk(i)] = max(currentA(use(i)));
        end
        S.cal = psm_calibration('model', pk, nm(use)');
        uialert(fig, ['The axis was estimated from the samples'' own peaks, so it is not an ', ...
            'independent calibration. Report it as approximate, or calibrate with lasers.'], ...
            'Estimated axis', 'Icon', 'info');
        updateLabels();  redraw();
        status(S.cal.info);
    end

    function removeCal()
        S.cal = psm_calibration('none');
        updateLabels();  redraw();  status('Calibration removed - axis in pixels.');
    end

%% ================= callbacks: measure =================
    function measureSelected()
        measure(selected());
    end

    function measure(names)
        if isempty(S.ref) || isempty(S.strip), error('Set the reference first (step 2).'); end
        done = 0;
        for i = 1:numel(names)
            nm = names{i};
            if strcmp(nm, S.ref.name) || (~isempty(S.dark) && strcmp(nm, S.dark.name)), continue; end
            status(sprintf('Measuring %s ...', nm));
            P = psm_loadPhoto(fullfile(S.folder, nm));
            [sh, ok] = psm_shift(P, S.ref, S.opt.align);
            notes = {};
            if ~ok, notes{end+1} = 'not aligned (no blue spot)'; end %#ok<AGROW>
            if ~isnan(P.exposure) && ~isnan(S.ref.exposure) && abs(P.exposure / S.ref.exposure - 1) > 0.05
                notes{end+1} = sprintf('exposure %.3g s vs ref %.3g s', P.exposure, S.ref.exposure); %#ok<AGROW>
            end
            if ~isnan(P.iso) && ~isnan(S.ref.iso) && P.iso ~= S.ref.iso
                notes{end+1} = sprintf('ISO %g vs ref %g', P.iso, S.ref.iso); %#ok<AGROW>
            end
            r0 = round(S.strip.roi + [sh(1) sh(1) sh(2) sh(2)]);
            r0 = max(r0, 1);  r0(2) = min(r0(2), size(P.sat, 1));  r0(4) = min(r0(4), size(P.sat, 2));
            if mean(P.sat(r0(1):r0(2), r0(3):r0(4)), 'all') > 0.01, notes{end+1} = 'overexposed'; end %#ok<AGROW>
            Is = psm_profile(P, S.strip, sh, S.opt.smooth) - S.Idark;
            Araw = psm_absorbance(Is, S.Iref, S.opt.minRef / 100);
            res = struct('name', nm, 'Is', Is, 'Araw', Araw, 'notes', strjoin(notes, '; '));
            j = find(strcmp({S.results.name}, nm), 1);
            if isempty(j), S.results(end+1) = res; else, S.results(j) = res; end
            showPhoto(P, sh);
            done = done + 1;
            clear P
        end
        refreshList();  redraw();
        msg = sprintf('%d photo(s) measured.', done);
        if any(~cellfun(@isempty, {S.results.notes}))
            msg = [msg ' See Notes in the table: different camera settings make absorbance values unreliable.'];
        end
        status(msg);
    end

    function A = currentA(i)
        A = psm_offset(S.results(i).Araw, S.opt.offset);
    end

    function setOffset(v)
        if startsWith(v, 'Auto'), S.opt.offset = 'auto'; else, S.opt.offset = 'none'; end
        redraw();
    end

    function setOpt(name, v)
        S.opt.(name) = v;
        if strcmp(name, 'align') && ~isempty(S.results)
            status('Setting changed - press "Measure selected photo(s)" again to apply it to earlier photos.');
        end
        if strcmp(name, 'minRef')
            for i = 1:numel(S.results)
                S.results(i).Araw = psm_absorbance(S.results(i).Is, S.Iref, v / 100);
            end
        end
        redraw();
    end

    function clearResults()
        S.results = S.results([]);  refreshList();  redraw();  status('Results cleared.');
    end

%% ================= callbacks: lab spectra, save, help =================
    function addLab()
        [f, d] = uigetfile({'*.csv;*.CSV;*.txt', 'Spectra (CSV/TXT)'}, 'Lab UV-Vis spectra', 'MultiSelect', 'on');
        figure(fig);
        if isequal(f, 0), return; end
        f = cellstr(f);
        for i = 1:numel(f)
            [wl, A] = psm_readSpectrumCSV(fullfile(d, f{i}));
            m = wl >= 380 & wl <= 800;  wl = wl(m);  A = A(m);
            A = A - mean(A(wl >= 750), 'omitnan');
            [~, n] = fileparts(f{i});
            S.lab(end+1) = struct('name', n, 'wl', wl, 'A', A);
        end
        redraw();
        if strcmp(S.cal.type, 'none')
            status('Lab spectra loaded. They will appear once the axis is calibrated in nm (step 4).');
        else
            status(sprintf('%d lab spectra added (baseline 750-800 nm removed).', numel(f)));
        end
    end

    function clearLab()
        S.lab = S.lab([]);  redraw();
    end

    function saveResults()
        if isempty(S.results), error('Nothing measured yet.'); end
        [f, d] = uiputfile('phone_spectra.csv', 'Save results as');
        figure(fig);
        if isequal(f, 0), return; end
        [~, b] = fileparts(f);
        n = numel(S.Iref);  px = (1:n)';
        T = table(px, 'VariableNames', {'pixel'});
        if ~strcmp(S.cal.type, 'none'), T.wavelength_nm = psm_wavelength(S.cal, px); end
        T.I_ref = S.Iref(:);
        for i = 1:numel(S.results)
            v = matlab.lang.makeValidName(erase(S.results(i).name, {'.jpg', '.jpeg', '.png', '.tif', '.tiff', '.JPG'}));
            T.(['I_' v])    = S.results(i).Is(:);
            T.(['Araw_' v]) = S.results(i).Araw(:);
            T.(['A_' v])    = currentA(i)';
        end
        writetable(T, fullfile(d, f));
        exportgraphics(axA,   fullfile(d, [b '_absorbance.png']), 'Resolution', 300);
        exportgraphics(axInt, fullfile(d, [b '_intensity.png']),  'Resolution', 300);
        writeLog(fullfile(d, [b '_log.txt']));
        status(['Saved ' f ', two PNG figures and a settings log in ' d]);
    end

    function writeLog(file)
        fid = fopen(file, 'w');
        fprintf(fid, 'Phone spectrometer %s - %s\n\n', appVersion, char(datetime('now')));
        fprintf(fid, 'Photo folder : %s\n', S.folder);
        fprintf(fid, 'Reference    : %s (exposure %g s, ISO %g)\n', S.ref.name, S.ref.exposure, S.ref.iso);
        if isempty(S.dark), fprintf(fid, 'Dark         : none\n');
        else, fprintf(fid, 'Dark         : %s\n', S.dark.name); end
        fprintf(fid, 'Strip        : rows %d-%d, cols %d-%d, vertical=%d, reversed=%d\n', S.strip.roi, S.strip.vertical, S.strip.reverse);
        fprintf(fid, 'Align on blue: %d\nIgnore below : %g %% of reference\nSmoothing    : %d px\n', S.opt.align, S.opt.minRef, S.opt.smooth);
        fprintf(fid, 'Offset       : %s\nCalibration  : %s\n\nSamples:\n', S.opt.offset, S.cal.info);
        for i = 1:numel(S.results)
            fprintf(fid, '  %s  %s\n', S.results(i).name, S.results(i).notes);
        end
        fclose(fid);
    end

    function saveSettings()
        [f, d] = uiputfile('spectrometer_settings.mat', 'Save settings');
        figure(fig);
        if isequal(f, 0), return; end
        st.folder = S.folder;  st.strip = S.strip;  st.cal = S.cal;  st.opt = S.opt;
        st.refName = '';  st.darkName = '';
        if ~isempty(S.ref),  st.refName  = S.ref.name;  end
        if ~isempty(S.dark), st.darkName = S.dark.name; end
        save(fullfile(d, f), '-struct', 'st');
        status(['Settings saved to ' f '. Load them next time to skip steps 2-4.']);
    end

    function loadSettings()
        [f, d] = uigetfile('*.mat', 'Load settings');
        figure(fig);
        if isequal(f, 0), return; end
        st = load(fullfile(d, f));
        S.opt = st.opt;  S.cal = st.cal;  S.folder = st.folder;
        efMin.Value = S.opt.minRef;
        if isfolder(S.folder) && ~isempty(st.refName) && isfile(fullfile(S.folder, st.refName))
            S.seen = listImages();
            S.ref = psm_loadPhoto(fullfile(S.folder, st.refName));
            S.strip = st.strip;
            if isempty(S.strip), S.strip = psm_findStrip(S.ref, S.opt.stripFrac); end
            if ~isempty(st.darkName) && isfile(fullfile(S.folder, st.darkName))
                S.dark = psm_loadPhoto(fullfile(S.folder, st.darkName));
            end
            updateReference();
            status('Settings loaded, reference reloaded. Go to step 5.');
        else
            refreshList();  updateLabels();
            status('Settings loaded, but the photo folder or reference was not found. Choose them again (steps 1-2).');
        end
    end

    function showHelp()
        h = fullfile(here, 'HOW_TO_USE.txt');
        if isfile(h), open(h); else, status('HOW_TO_USE.txt not found next to the app.'); end
    end

    function onClose(~, ~)
        try, stop(tmr); delete(tmr); catch, end
        delete(fig);
    end

%% ================= layout helpers =================
    function h = addHead(txt)
        r = r + 1;  h = uilabel(L, 'Text', txt, 'FontWeight', 'bold');
        h.Layout.Row = r;  h.Layout.Column = [1 2];
    end
    function b = addBtn(txt, cb, col)
        if nargin < 3, col = [1 2]; end
        if ~(isscalar(col) && col == 2), r = r + 1; end      % column 2 shares the row
        b = uibutton(L, 'Text', txt, 'ButtonPushedFcn', @(~, ~) safe(cb));
        b.Layout.Row = r;  b.Layout.Column = col;
    end
    function c = addChk(txt, val, cb)
        r = r + 1;  c = uicheckbox(L, 'Text', txt, 'Value', val, 'ValueChangedFcn', @(s, ~) safe(@() cb(s.Value)));
        c.Layout.Row = r;  c.Layout.Column = [1 2];
    end
    function t = addInfo(txt)
        r = r + 1;  t = uilabel(L, 'Text', txt, 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35]);
        t.Layout.Row = r;  t.Layout.Column = [1 2];
    end

%% ================= drawing =================
    function showPhoto(P, sh)
        cla(axImg);  image(axImg, P.thumb);  axis(axImg, 'image');
        axImg.XTick = [];  axImg.YTick = [];
        title(axImg, P.name, 'Interpreter', 'none');
        if ~isempty(S.strip)
            k = P.thumbStep;
            rr = (S.strip.roi(1:2) + sh(1)) / k;  cc = (S.strip.roi(3:4) + sh(2)) / k;
            rectangle(axImg, 'Position', [cc(1) rr(1) diff(cc) diff(rr)], 'EdgeColor', 'w', 'LineWidth', 1.5);
        end
    end

    function redraw()
        cla(axInt);  cla(axA);  legend(axInt, 'off');  legend(axA, 'off');
        if isempty(S.Iref), tbl.Data = {}; return; end
        n = numel(S.Iref);  px = 1:n;
        x = psm_wavelength(S.cal, px);
        calibrated = ~strcmp(S.cal.type, 'none');
        if calibrated, xl = 'Wavelength (nm)'; else, xl = 'Position along rainbow (px, blue \rightarrow red)'; end
        cols = lines(max(1, numel(S.results)));
        hold(axInt, 'on');
        plot(axInt, x, S.Iref, 'k', 'LineWidth', 1.8, 'DisplayName', 'Reference');
        hold(axA, 'on');
        rows = cell(numel(S.results), 4);
        for i = 1:numel(S.results)
            A = currentA(i);
            [am, j] = max(A);
            if S.opt.normalise && am > 0, A = A / am; end
            plot(axInt, x, S.results(i).Is, 'Color', cols(i, :), 'DisplayName', S.results(i).name);
            plot(axA, x, A, 'Color', cols(i, :), 'LineWidth', 1.8, 'DisplayName', S.results(i).name);
            if calibrated, pkTxt = sprintf('%.0f nm', x(j)); else, pkTxt = sprintf('%d px', j); end
            rows(i, :) = {S.results(i).name, pkTxt, round(am, 2), S.results(i).notes};
        end
        if calibrated
            for i = 1:numel(S.lab)
                A = S.lab(i).A;  if S.opt.normalise, A = A / max(A); end
                plot(axA, S.lab(i).wl, A, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.2, 'DisplayName', ['lab: ' S.lab(i).name]);
            end
            xlim(axA, [min(x) max(x)]);  xlim(axInt, [min(x) max(x)]);
        end
        yline(axA, 0, ':', 'HandleVisibility', 'off');
        xlabel(axInt, xl);  xlabel(axA, xl);
        if S.opt.normalise, ylabel(axA, 'Normalised absorbance'); else, ylabel(axA, 'Absorbance'); end
        legend(axInt, 'Interpreter', 'none', 'Location', 'best');
        if ~isempty(S.results) || (calibrated && ~isempty(S.lab))
            legend(axA, 'Interpreter', 'none', 'Location', 'best');
        end
        tbl.Data = rows;
    end

    function updateLabels()
        t = 'Reference: none.';
        if ~isempty(S.ref)
            t = sprintf('Reference: %s (%s s, ISO %g).', S.ref.name, num2str(S.ref.exposure, 3), S.ref.iso);
        end
        if isempty(S.dark), t = [t '  Dark: none (optional).']; else, t = [t '  Dark: ' S.dark.name '.']; end
        lblRef.Text = t;
        lblCal.Text = S.cal.info;
    end

    function status(msg, isErr)
        if nargin < 2, isErr = false; end
        lblStatus.Text = msg;
        if isErr, lblStatus.FontColor = [0.75 0.1 0.1]; else, lblStatus.FontColor = [0.1 0.1 0.1]; end
        drawnow limitrate;
    end

    function safe(fn)
        % run a callback; show problems as a message instead of crashing
        fig.Pointer = 'watch';  drawnow;
        try
            fn();
        catch err
            uialert(fig, err.message, 'Something needs attention');
            status(err.message, true);
        end
        fig.Pointer = 'arrow';
    end
end
