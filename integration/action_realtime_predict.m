function result = action_realtime_predict(appState, params)
%ACTION_REALTIME_PREDICT Capture or reuse a frame, detect, align, and predict.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    result = struct('status', "error", 'message', "实时识别未开始。", 'appState', [], ...
        'sourceImage', [], 'faceImage', [], 'singleText', {{}});

    try
        [frame, frameMessage] = get_realtime_frame(appState);
        if isempty(frame)
            result.status = "no_frame";
            result.message = frameMessage;
            return;
        end

        faceInfo = detect_face(frame, struct());
        if string(faceInfo.status) ~= "ok"
            appState.currentCameraFrame = frame;
            appState.currentImage = frame;
            appState.currentFaceInfo = faceInfo;
            result.status = string(faceInfo.status);
            result.message = string(faceInfo.message);
            result.appState = appState;
            result.sourceImage = frame;
            return;
        end

        alignInfo = align_face(frame, faceInfo, struct('imageSize', [112, 92]));
        if string(alignInfo.status) ~= "ok"
            result.status = string(alignInfo.status);
            result.message = string(alignInfo.message);
            result.appState = appState;
            result.sourceImage = frame;
            return;
        end

        model = ensure_model(appState, params);
        predictResult = predict_face_identity(model, alignInfo.alignedFace, struct());

        appState.model = model;
        appState.currentCameraFrame = frame;
        appState.currentImage = frame;
        appState.currentFaceInfo = faceInfo;
        appState.currentFaceBox = faceInfo.faceBox;
        appState.currentAlignInfo = alignInfo;
        appState.currentAlignedFace = alignInfo.alignedFace;
        appState.realtimeResult = predictResult;
        appState.lastReplayPackage = export_replay_state(frame, faceInfo, alignInfo);

        result.status = string(get_field_or(predictResult, 'status', "ok"));
        result.message = string(get_field_or(predictResult, 'message', "实时识别完成。"));
        result.appState = appState;
        result.sourceImage = frame;
        result.faceImage = alignInfo.alignedFace;
        result.singleText = build_single_text(predictResult);
    catch ME
        result.status = "error";
        result.message = "实时识别失败: " + string(ME.message);
    end
end

function [frame, message] = get_realtime_frame(appState)
    frame = [];
    message = "";

    if isfield(appState, 'camera') && ~isempty(appState.camera)
        [frame, message] = camera_snapshot(appState.camera);
        return;
    end
    if isfield(appState, 'currentCameraFrame') && ~isempty(appState.currentCameraFrame)
        frame = appState.currentCameraFrame;
        message = "使用已有摄像头帧。";
        return;
    end
    if isfield(appState, 'currentImage') && ~isempty(appState.currentImage)
        frame = appState.currentImage;
        message = "使用当前输入图像作为实时识别帧。";
        return;
    end
    message = "没有可用于实时识别的图像或摄像头帧。";
end

function model = ensure_model(appState, params)
    if isfield(appState, 'model') && isstruct(appState.model) && ...
            isfield(appState.model, 'status') && string(appState.model.status) ~= "todo" && ...
            string(appState.model.status) ~= ""
        model = appState.model;
        return;
    end

    trainDir = fullfile(appState.rootDir, 'data', 'train');
    if ~isfolder(trainDir)
        trainDir = fullfile(appState.rootDir, 'data');
    end
    pcaDim = get_param_or(params, 'pcaDim', appState.defaultPcaDim);
    svmC = get_param_or(params, 'svmC', appState.defaultSvmC);
    model = train_pca_svm_model(trainDir, pcaDim, svmC, struct());
end

function textLines = build_single_text(predictResult)
    name = string(get_field_or(predictResult, 'name', ""));
    if strlength(name) == 0
        name = "-";
    end
    elapsedMs = get_field_or(predictResult, 'elapsedMs', []);
    elapsedText = "-";
    if ~isempty(elapsedMs)
        elapsedText = sprintf('%.2f ms', elapsedMs);
    end

    textLines = {
        char("预测姓名: " + name)
        char("Top-3: " + format_topk(get_field_or(predictResult, 'topKNames', {}), get_field_or(predictResult, 'topKScores', [])))
        ['单张耗时: ', elapsedText]
    };
end

function topKText = format_topk(topKNames, topKScores)
    if isempty(topKNames)
        topKText = "-";
        return;
    end
    if isstring(topKNames) || ischar(topKNames)
        names = cellstr(topKNames);
    else
        names = topKNames;
    end
    parts = strings(1, numel(names));
    for i = 1:numel(names)
        if ~isempty(topKScores) && numel(topKScores) >= i
            parts(i) = string(names{i}) + sprintf('(%.3f)', topKScores(i));
        else
            parts(i) = string(names{i});
        end
    end
    topKText = strjoin(parts, ', ');
end

function value = get_param_or(params, fieldName, defaultValue)
    if isstruct(params) && isfield(params, fieldName) && ~isempty(params.(fieldName))
        value = params.(fieldName);
    else
        value = defaultValue;
    end
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
