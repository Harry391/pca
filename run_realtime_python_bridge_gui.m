function run_realtime_python_bridge_gui(maxFrames)
%RUN_REALTIME_PYTHON_BRIDGE_GUI MATLAB GUI with Python camera/alignment bridge.
%
% Python owns capture + face alignment. MATLAB polls the latest aligned face
% and runs the existing hand-written PCA/SVM recognizer.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(maxFrames)
        maxFrames = inf;
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();

    model = load_or_train_model(rootDir, options);
    bridge = start_python_bridge(rootDir);
    cleanup = onCleanup(@() stop_python_bridge(bridge));

    fig = figure('Name', 'MATLAB GUI + Python Bridge + PCA/SVM', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'KeyPressFcn', @(src, event) setappdata(src, 'lastKey', event.Key));
    setappdata(fig, 'lastKey', '');

    frameIndex = 0;
    lastSequence = -1;
    fps = 0;
    lastTic = tic;

    fprintf('Python bridge realtime started. Press q or close window to exit.\n');

    while ishandle(fig) && frameIndex < maxFrames
        if strcmp(getappdata(fig, 'lastKey'), 'q')
            break;
        end

        meta = read_bridge_meta(bridge.metaPath);
        if ~isempty(meta) && isfield(meta, 'sequence') && meta.sequence ~= lastSequence
            lastSequence = meta.sequence;
            frameIndex = frameIndex + 1;

            rawFrame = safe_imread(bridge.rawFramePath);
            alignedFace = safe_imread(bridge.alignedFacePath);
            if isempty(alignedFace)
                pause(0.03);
                continue;
            end

            pred = predict_face_identity(model, alignedFace, options);
            result = struct();
            result.status = pred.status;
            result.message = pred.message;
            result.name = pred.name;
            result.topKNames = pred.topKNames;
            result.topKScores = pred.topKScores;
            result.faceBox = get_option(meta, 'faceBox', []);
            result.alignedFace = alignedFace;
            result.alignStatus = sprintf('python_bridge | %s', get_option(meta, 'status', 'unknown'));
            result.elapsedMs = get_option(meta, 'processMs', 0);
            result.predElapsedMs = pred.elapsedMs;

            elapsed = toc(lastTic);
            if elapsed > 0
                fps = 0.85 * fps + 0.15 * (1 / elapsed);
            end
            lastTic = tic;

            show_bridge_layout(rawFrame, result, fps, frameIndex);
            drawnow limitrate;

            fprintf('#%04d seq=%d %.1ffps | %s | %s\n', ...
                frameIndex, meta.sequence, fps, result.alignStatus, format_top3_inline(result));
        else
            pause(0.03);
        end
    end

    fprintf('Python bridge realtime stopped.\n');
end

function model = load_or_train_model(rootDir, options)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_tight_masked_v11_model.mat');
    loaded = model_io('load', [], modelPath);
    if strcmp(loaded.status, 'ok')
        model = loaded.model;
        return;
    end

    trainDir = fullfile(rootDir, 'data', 'python_tight_masked_pca_svm_split_v11', 'train');
    if ~isfolder(trainDir)
        report = run_tight_masked_pca_svm_experiment();
        model = report.model;
        return;
    end

    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('Model training failed: %s', model.message);
    end
    model_io('save', model, modelPath);
end

function bridge = start_python_bridge(rootDir)
    sessionDir = fullfile(rootDir, 'results', 'python_camera_bridge');
    if ~isfolder(sessionDir)
        mkdir(sessionDir);
    end

    bridge.sessionDir = sessionDir;
    bridge.rawFramePath = fullfile(sessionDir, 'latest_raw.jpg');
    bridge.alignedFacePath = fullfile(sessionDir, 'latest_aligned.png');
    bridge.metaPath = fullfile(sessionDir, 'latest_meta.json');
    bridge.stopFlagPath = fullfile(sessionDir, 'stop.flag');
    bridge.proc = [];

    pythonExe = pick_python_executable();
    scriptPath = fullfile(rootDir, 'preprocess', 'python_camera_bridge.py');
    taskFile = fullfile(fileparts(rootDir), 'face_landmarker.task');
    if ~isfile(taskFile)
        error('Missing MediaPipe task file: %s', taskFile);
    end

    cameraIndexText = strtrim(getenv('CODEX_PYTHON_CAMERA_INDEX'));
    stdoutLog = fullfile(sessionDir, 'bridge_stdout.log');
    stderrLog = fullfile(sessionDir, 'bridge_stderr.log');
    launcherPath = fullfile(sessionDir, 'launch_bridge.bat');
    if isfile(bridge.stopFlagPath)
        delete(bridge.stopFlagPath);
    end
    delete_if_exists(bridge.metaPath);
    delete_if_exists(stdoutLog);
    delete_if_exists(stderrLog);
    delete_if_exists(launcherPath);

    if ispc
        write_bridge_launcher(launcherPath, pythonExe, scriptPath, sessionDir, taskFile, cameraIndexText, rootDir, stdoutLog, stderrLog);
        [status, out] = system(sprintf('cmd /c start "" /b "%s"', launcherPath));
        if status ~= 0
            error('Failed to start python bridge: %s', out);
        end
    else
        cmd = sprintf('"%s" "%s" --session-dir "%s" --task-file "%s"', ...
            pythonExe, scriptPath, sessionDir, taskFile);
        if ~isempty(cameraIndexText)
            cmd = sprintf('%s --camera-index %s', cmd, cameraIndexText);
        end
        [status, out] = system([cmd, ' > "', stdoutLog, '" 2> "', stderrLog, '" &']);
        if status ~= 0
            error('Failed to start python bridge: %s', out);
        end
    end

    meta = wait_for_bridge_start(bridge.metaPath, stdoutLog, stderrLog, 12.0);
    if isempty(meta)
        logText = read_bridge_logs(stdoutLog, stderrLog);
        if isempty(strtrim(logText))
            error('Python bridge did not produce metadata. Check Python environment and camera access.');
        end
        error('Python bridge did not produce metadata. Logs:%s', newline + string(logText));
    end
    statusText = get_option(meta, 'status', '');
    if any(strcmp(statusText, {'stopped', 'camera_read_failed', 'startup_error'}))
        error('Python bridge startup failed: %s', get_option(meta, 'message', statusText));
    end
end

function meta = wait_for_bridge_start(metaPath, stdoutLog, stderrLog, timeoutSec)
    meta = [];
    ticHandle = tic;
    while toc(ticHandle) < timeoutSec
        meta = read_bridge_meta(metaPath);
        if ~isempty(meta)
            return;
        end

        logText = read_bridge_logs(stdoutLog, stderrLog);
        if contains(string(logText), 'Traceback') || contains(string(logText), 'RuntimeError') || contains(string(logText), 'can''t open file')
            return;
        end
        pause(0.25);
    end
end

function stop_python_bridge(bridge)
    if isempty(bridge) || ~isstruct(bridge)
        return;
    end

    try
        if isfield(bridge, 'stopFlagPath') && ~isempty(bridge.stopFlagPath)
            fid = fopen(bridge.stopFlagPath, 'w');
            if fid > 0
                fprintf(fid, 'stop\n');
                fclose(fid);
            end
        end
    catch
    end
end

function delete_if_exists(path)
    if isfile(path)
        delete(path);
    end
end

function write_bridge_launcher(launcherPath, pythonExe, scriptPath, sessionDir, taskFile, cameraIndexText, rootDir, stdoutLog, stderrLog)
    argString = sprintf('"%s" --session-dir "%s" --task-file "%s"', scriptPath, sessionDir, taskFile);
    if ~isempty(cameraIndexText)
        argString = sprintf('%s --camera-index %s', argString, cameraIndexText);
    end
    lines = {
        '@echo off'
        'setlocal'
        sprintf('cd /d "%s"', rootDir)
        sprintf('"%s" %s 1>>"%s" 2>>"%s"', pythonExe, argString, stdoutLog, stderrLog)
    };
    fid = fopen(launcherPath, 'w');
    if fid < 0
        error('Failed to create launcher: %s', launcherPath);
    end
    cleanup = onCleanup(@() fclose(fid));
    for i = 1:numel(lines)
        fprintf(fid, '%s\r\n', lines{i});
    end
    clear cleanup;
end

function pythonExe = pick_python_executable()
    envPython = strtrim(getenv('PYTHON_EXE'));
    if ~isempty(envPython)
        [status, ~] = system(['"', envPython, '" --version']);
        if status == 0
            pythonExe = envPython;
            return;
        end
    end

    if ispc
        [status, out] = system('where python');
        if status == 0
            lines = regexp(strtrim(out), '\r\n|\n|\r', 'split');
            lines = lines(~cellfun(@isempty, lines));
            if ~isempty(lines)
                pythonExe = strtrim(lines{1});
                return;
            end
        end
    end

    [status, ~] = system('python --version');
    if status == 0
        pythonExe = 'python';
        return;
    end

    error('No usable python executable found. Set PYTHON_EXE first.');
end

function meta = read_bridge_meta(metaPath)
    meta = [];
    if ~isfile(metaPath)
        return;
    end

    try
        text = fileread(metaPath);
        meta = jsondecode(text);
    catch
        meta = [];
    end
end

function text = read_bridge_logs(stdoutLog, stderrLog)
    parts = {};
    if isfile(stdoutLog)
        try
            outText = strtrim(fileread(stdoutLog));
            if ~isempty(outText)
                parts{end + 1} = sprintf('[stdout]\n%s', outText); %#ok<AGROW>
            end
        catch
        end
    end
    if isfile(stderrLog)
        try
            errText = strtrim(fileread(stderrLog));
            if ~isempty(errText)
                parts{end + 1} = sprintf('[stderr]\n%s', errText); %#ok<AGROW>
            end
        catch
        end
    end
    if isempty(parts)
        text = '';
    else
        text = strjoin(parts, newline + newline);
    end
end

function img = safe_imread(path)
    img = [];
    if ~isfile(path)
        return;
    end

    try
        img = imread(path);
    catch
        img = [];
    end
end

function show_bridge_layout(rawFrame, result, fps, frameIndex)
    subplot(1, 2, 1);
    if isempty(rawFrame)
        imshow(zeros(10, 10));
    else
        imshow(rawFrame, []);
        hold on;
        if ~isempty(result.faceBox) && numel(result.faceBox) == 4
            rectangle('Position', result.faceBox, 'EdgeColor', 'g', 'LineWidth', 2);
        end
        hold off;
    end
    title(sprintf('Python Capture | FPS %.1f | #%d', fps, frameIndex), 'Interpreter', 'none');

    subplot(1, 2, 2);
    imshow(result.alignedFace, []);
    title(build_right_title(result, frameIndex), 'Interpreter', 'none');
end

function titleText = build_right_title(result, frameIndex)
    lines = { ...
        sprintf('Python Bridge Input | Frame %d', frameIndex), ...
        sprintf('Align: %s | %.2f ms', result.alignStatus, result.elapsedMs)};

    topCount = min(3, numel(result.topKNames));
    for i = 1:topCount
        lines{end + 1} = sprintf('%d. %s (%.4f)', i, result.topKNames{i}, result.topKScores(i)); %#ok<AGROW>
    end

    titleText = lines;
end

function text = format_top3_inline(result)
    parts = {};
    topCount = min(3, numel(result.topKNames));
    for i = 1:topCount
        parts{end + 1} = sprintf('%d.%s(%.4f)', i, result.topKNames{i}, result.topKScores(i)); %#ok<AGROW>
    end

    if isempty(parts)
        text = 'no prediction';
    else
        text = strjoin(parts, ' | ');
    end
end

function value = get_option(options, name, defaultValue)
    if isstruct(options) && isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function text = ps_quote(value)
    text = ['''', strrep(value, '''', ''''''), ''''];
end
