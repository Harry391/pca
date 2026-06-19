function run_realtime_camera_preview(maxFrames)
%RUN_REALTIME_CAMERA_PREVIEW Live camera preview with PCA/SVM prediction.
%
% Left panel: raw camera frame.
% Right panel: the exact preprocessed face image passed to the recognizer.
%
% Usage:
%   run_realtime_camera_preview
%   run_realtime_camera_preview(500)

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
    cam = open_camera();
    cleanup = onCleanup(@() close_camera(cam));
    detector = create_face_detector();

    fig = figure('Name', 'Realtime PCA/SVM Preview', 'NumberTitle', 'off', ...
        'Color', 'w', 'KeyPressFcn', @(src, event) setappdata(src, 'lastKey', event.Key));
    setappdata(fig, 'lastKey', '');

    frameIndex = 0;
    lastTic = tic;
    fps = 0;

    fprintf('实时识别预览已启动。关闭窗口或按 q 退出。\n');

    while ishandle(fig) && frameIndex < maxFrames
        if strcmp(getappdata(fig, 'lastKey'), 'q')
            break;
        end

        frameIndex = frameIndex + 1;
        frame = capture_frame(cam);
        [faceCrop, faceBox, faceMode] = extract_face_for_realtime(frame, detector);

        input = preprocess_for_model(faceCrop, struct('imageSize', model.imageSize));
        pred = predict_face_identity(model, faceCrop, options);

        elapsed = toc(lastTic);
        if elapsed > 0
            fps = 0.85 * fps + 0.15 * (1 / elapsed);
        end
        lastTic = tic;

        show_preview(frame, faceBox, input.image, pred, faceMode, fps, frameIndex);
        drawnow limitrate;
    end

    fprintf('实时识别预览已结束。\n');
end

function model = load_or_train_model(rootDir, options)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_model.mat');
    modelOut = model_io('load', [], modelPath);
    if strcmp(modelOut.status, 'ok')
        model = modelOut.model;
        return;
    end

    fprintf('未找到已训练模型，先自动训练一次...\n');
    trainDir = fullfile(rootDir, 'data', 'aligned_faces', 'train');
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

function show_preview(frame, faceBox, modelFace, pred, faceMode, fps, frameIndex)
    subplot(1, 2, 1);
    imshow(frame);
    hold on;
    rectangle('Position', faceBox, 'EdgeColor', 'g', 'LineWidth', 2);
    title(sprintf('原始摄像头 | %s | FPS %.1f', faceMode, fps), 'Interpreter', 'none');
    hold off;

    subplot(1, 2, 2);
    imshow(modelFace, []);
    title(sprintf('识别输入 112x92 | %s | %.2f ms | #%d', ...
        pred.name, pred.elapsedMs, frameIndex), 'Interpreter', 'none');
end
