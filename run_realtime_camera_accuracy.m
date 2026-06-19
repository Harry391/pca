function realtimeResult = run_realtime_camera_accuracy(expectedName, sampleCount, intervalSec)
%RUN_REALTIME_CAMERA_ACCURACY Test recognition accuracy from webcam frames.
%
% Usage:
%   run_realtime_camera_accuracy
%   run_realtime_camera_accuracy('张三', 20, 0.5)

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(expectedName)
        expectedName = input('请输入当前摄像头前的真实姓名: ', 's');
    end
    if nargin < 2 || isempty(sampleCount)
        sampleCount = 20;
    end
    if nargin < 3 || isempty(intervalSec)
        intervalSec = 0.5;
    end

    modelPath = fullfile(rootDir, 'models', 'pca_svm_model.mat');
    resultsDir = fullfile(rootDir, 'results');
    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    modelOut = model_io('load', [], modelPath);
    if ~strcmp(modelOut.status, 'ok')
        fprintf('未找到已训练模型，先自动训练一次...\n');
        trainDir = fullfile(rootDir, 'data', 'aligned_faces', 'train');
        options = default_realtime_options();
        model = train_pca_svm_model(trainDir, 120, 0.03, options);
        if ~strcmp(model.status, 'ok')
            error('模型训练失败: %s', model.message);
        end
        model_io('save', model, modelPath);
    else
        model = modelOut.model;
        options = default_realtime_options();
    end

    cam = open_camera();
    cleanup = onCleanup(@() close_camera(cam));
    detector = create_face_detector();

    fprintf('真实姓名: %s\n', expectedName);
    fprintf('采集 %d 帧，每 %.2f 秒识别一次。关闭窗口或 Ctrl+C 可中断。\n', sampleCount, intervalSec);

    fig = figure('Name', 'Realtime PCA/SVM Accuracy Test', 'NumberTitle', 'off');
    rows = struct('index', {}, 'trueName', {}, 'predName', {}, 'isCorrect', {}, ...
        'elapsedMs', {}, 'faceMode', {}, 'imagePath', {});

    correctCount = 0;
    for i = 1:sampleCount
        if ~ishandle(fig)
            break;
        end

        frame = capture_frame(cam);
        [faceImg, faceBox, faceMode] = extract_face_for_realtime(frame, detector);
        pred = predict_face_identity(model, faceImg, options);
        isCorrect = strcmp(pred.name, expectedName);
        correctCount = correctCount + double(isCorrect);

        framePath = fullfile(resultsDir, sprintf('realtime_%s_%03d.jpg', expectedName, i));
        imwrite(faceImg, framePath);

        rows(end + 1).index = i; %#ok<AGROW>
        rows(end).trueName = expectedName;
        rows(end).predName = pred.name;
        rows(end).isCorrect = isCorrect;
        rows(end).elapsedMs = pred.elapsedMs;
        rows(end).faceMode = faceMode;
        rows(end).imagePath = framePath;

        show_realtime_frame(frame, faceBox, expectedName, pred.name, isCorrect, i, sampleCount);
        drawnow;
        fprintf('%02d/%02d true=%s pred=%s correct=%d mode=%s time=%.2fms\n', ...
            i, sampleCount, expectedName, pred.name, isCorrect, faceMode, pred.elapsedMs);

        pause(intervalSec);
    end

    totalCount = numel(rows);
    if totalCount == 0
        accuracy = NaN;
    else
        accuracy = correctCount / totalCount;
    end

    resultPath = fullfile(resultsDir, 'realtime_camera_results.csv');
    export_realtime_rows(rows, resultPath);

    realtimeResult = struct();
    realtimeResult.status = 'ok';
    realtimeResult.message = 'realtime camera test completed';
    realtimeResult.trueName = expectedName;
    realtimeResult.accuracy = accuracy;
    realtimeResult.correctCount = correctCount;
    realtimeResult.totalCount = totalCount;
    realtimeResult.perFrameResults = rows;
    realtimeResult.resultPath = resultPath;

    fprintf('实时采集准确率: %.2f%% (%d/%d)\n', accuracy * 100, correctCount, totalCount);
    fprintf('结果文件: %s\n', resultPath);
end

function options = default_realtime_options()
    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();
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

    error(['未能打开摄像头。可选方案：安装 MATLAB Support Package for USB Webcams，', ...
        '或安装/启用 Image Acquisition Toolbox 的 winvideo 适配器。']);
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

function detector = create_face_detector()
    detector = [];
    if exist('vision.CascadeObjectDetector', 'class') == 8
        detector = vision.CascadeObjectDetector('FrontalFaceCART');
        detector.MergeThreshold = 4;
    end
end

function [faceImg, faceBox, faceMode] = extract_face_for_realtime(frame, detector)
    faceBox = [];
    faceMode = 'center_crop';

    if ~isempty(detector)
        boxes = step(detector, frame);
        if ~isempty(boxes)
            areas = boxes(:, 3) .* boxes(:, 4);
            [~, idx] = max(areas);
            faceBox = expand_square_box(boxes(idx, :), size(frame), 0.35);
            faceMode = 'haar_face';
        end
    end

    if isempty(faceBox)
        faceBox = center_square_box(size(frame), 0.72);
    end

    x = faceBox(1);
    y = faceBox(2);
    w = faceBox(3);
    h = faceBox(4);
    faceImg = frame(y:y + h - 1, x:x + w - 1, :);
end

function box = expand_square_box(box, imageSize, padding)
    x = double(box(1));
    y = double(box(2));
    w = double(box(3));
    h = double(box(4));
    imgH = imageSize(1);
    imgW = imageSize(2);

    side = max(w, h) * (1 + 2 * padding);
    cx = x + w / 2;
    cy = y + h / 2;
    x1 = round(cx - side / 2);
    y1 = round(cy - side / 2);
    x1 = max(1, min(imgW - round(side) + 1, x1));
    y1 = max(1, min(imgH - round(side) + 1, y1));
    side = min([round(side), imgW - x1 + 1, imgH - y1 + 1]);
    box = [x1, y1, side, side];
end

function box = center_square_box(imageSize, ratio)
    imgH = imageSize(1);
    imgW = imageSize(2);
    side = round(min(imgH, imgW) * ratio);
    x = round((imgW - side) / 2) + 1;
    y = round((imgH - side) / 2) + 1;
    box = [x, y, side, side];
end

function show_realtime_frame(frame, faceBox, trueName, predName, isCorrect, index, total)
    imshow(frame);
    hold on;
    rectangle('Position', faceBox, 'EdgeColor', ternary_color(isCorrect), 'LineWidth', 2);
    title(sprintf('%02d/%02d true: %s | pred: %s | correct: %d', ...
        index, total, trueName, predName, isCorrect), 'Interpreter', 'none');
    hold off;
end

function color = ternary_color(isCorrect)
    if isCorrect
        color = 'g';
    else
        color = 'r';
    end
end

function export_realtime_rows(rows, resultPath)
    fid = fopen(resultPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'index,trueName,predName,isCorrect,elapsedMs,faceMode,imagePath\n');
    for i = 1:numel(rows)
        fprintf(fid, '%d,%s,%s,%d,%.6f,%s,%s\n', ...
            rows(i).index, ...
            csv_escape(rows(i).trueName), ...
            csv_escape(rows(i).predName), ...
            rows(i).isCorrect, ...
            rows(i).elapsedMs, ...
            csv_escape(rows(i).faceMode), ...
            csv_escape(rows(i).imagePath));
    end
    clear cleanup;
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
