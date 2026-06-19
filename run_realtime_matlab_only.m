function run_realtime_matlab_only(maxFrames)
%RUN_REALTIME_MATLAB_ONLY Realtime recognition with MATLAB-only alignment.
%
% Left: raw camera frame. Right: MATLAB-aligned recognizer input.
% Press q or close the window to quit.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(maxFrames)
        maxFrames = inf;
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.detectorMode = 'fast';
    options.useEqualizedSearch = false;
    options.minFaceRatio = 0.68;
    options.facePadding = 0.18;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = {};

    try
        model = load_or_train_auto_points_model(rootDir, options);
    catch err
        error('实时识别模型准备失败: %s', err.message);
    end
    cam = open_camera();
    cleanup = onCleanup(@() close_camera(cam));

    fig = figure('Name', 'MATLAB-only Realtime PCA/SVM', ...
        'NumberTitle', 'off', 'Color', 'w', ...
        'KeyPressFcn', @(src, event) setappdata(src, 'lastKey', event.Key));
    setappdata(fig, 'lastKey', '');

    frameIndex = 0;
    lastTic = tic;
    fps = 0;

    fprintf('MATLAB-only 实时识别已启动。按 q 或关闭窗口退出。\n');
    fprintf('模型类别数: %d | 训练来源: %s\n', numel(model.labels), model.trainDir);

    while ishandle(fig) && frameIndex < maxFrames
        if strcmp(getappdata(fig, 'lastKey'), 'q')
            break;
        end

        frameIndex = frameIndex + 1;
        frame = capture_frame(cam);
        result = realtime_matlab_align_and_predict(model, frame, options);

        elapsed = toc(lastTic);
        if elapsed > 0
            fps = 0.85 * fps + 0.15 * (1 / elapsed);
        end
        lastTic = tic;

        show_realtime_layout(frame, result, fps, frameIndex);
        drawnow limitrate;

        fprintf('#%04d %.1ffps %.2fms | %s | %s\n', ...
            frameIndex, fps, result.alignAndPredictMs, result.alignStatus, format_top3_inline(result));
    end

    fprintf('MATLAB-only 实时识别已结束。\n');
end

function model = load_or_train_auto_points_model(rootDir, options)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_auto_points_model.mat');
    loaded = model_io('load', [], modelPath);
    if strcmp(loaded.status, 'ok')
        model = loaded.model;
        return;
    end

    trainDir = fullfile(rootDir, 'data', 'matlab_auto_points_pca_svm_split', 'train');
    if ~isfolder(trainDir)
        fprintf('未找到 auto-points split，先生成一次实验划分并训练模型...\n');
        report = run_auto_points_pca_svm_experiment();
        model = report.model;
        return;
    end

    fprintf('未找到 auto-points 模型，正在从 %s 训练...\n', trainDir);
    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('模型训练失败: %s', model.message);
    end
    model_io('save', model, modelPath);
end

function cam = open_camera()
    cam = struct('type', '', 'handle', []);

    try
        cams = webcamlist;
        if ~isempty(cams)
            fprintf('使用 webcam 接口: %s\n', cams{1});
            cam.type = 'webcam';
            cam.handle = webcam(1);
            return;
        end
    catch err
        fprintf('webcam 接口不可用: %s\n', err.message);
    end

    if exist('videoinput', 'file') == 2
        try
            info = imaqhwinfo;
            adaptor = pick_video_adaptor(info);
            if ~isempty(adaptor)
                adaptorInfo = imaqhwinfo(adaptor);
                deviceId = adaptorInfo.DeviceIDs{1};
                fprintf('使用 videoinput 接口: %s device %d\n', adaptor, deviceId);
                vid = videoinput(adaptor, deviceId);
                triggerconfig(vid, 'manual');
                vid.FramesPerTrigger = 1;
                start(vid);
                cam.type = 'videoinput';
                cam.handle = vid;
                return;
            end
        catch err
            fprintf('videoinput 接口不可用: %s\n', err.message);
        end
    end

    error(['未能打开摄像头。笔记本内置摄像头在 MATLAB 中通常仍需要 ', ...
        'MATLAB Support Package for USB Webcams，或 Image Acquisition Toolbox 的 winvideo 适配器。']);
end

function close_camera(cam)
    if isempty(cam) || ~isstruct(cam) || isempty(cam.handle)
        return;
    end

    if strcmp(cam.type, 'videoinput')
        try
            stop(cam.handle);
            delete(cam.handle);
        catch
        end
    elseif strcmp(cam.type, 'webcam')
        try
            clear cam;
        catch
        end
    end
end

function frame = capture_frame(cam)
    switch cam.type
        case 'webcam'
            frame = snapshot(cam.handle);
        case 'videoinput'
            frame = getsnapshot(cam.handle);
        otherwise
            error('未知摄像头后端。');
    end
end

function adaptor = pick_video_adaptor(info)
    adaptor = '';
    installed = info.InstalledAdaptors;
    preferred = {'winvideo', 'macvideo', 'linuxvideo'};
    for i = 1:numel(preferred)
        if any(strcmp(installed, preferred{i}))
            adaptor = preferred{i};
            return;
        end
    end
    if ~isempty(installed)
        adaptor = installed{1};
    end
end

function show_realtime_layout(frame, result, fps, frameIndex)
    subplot(1, 2, 1);
    imshow(frame, []);
    hold on;
    if ~isempty(result.faceBox)
        rectangle('Position', result.faceBox, 'EdgeColor', 'g', 'LineWidth', 2);
    end
    title(sprintf('原始摄像头 | FPS %.1f | #%d', fps, frameIndex), 'Interpreter', 'none');
    hold off;

    subplot(1, 2, 2);
    imshow(result.alignedFace, []);
    title(build_right_title(result, frameIndex), 'Interpreter', 'none');
end

function titleText = build_right_title(result, frameIndex)
    lines = { ...
        sprintf('MATLAB 对齐输入 | Frame %d', frameIndex), ...
        sprintf('Time: %.2f ms', result.alignAndPredictMs)};

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
