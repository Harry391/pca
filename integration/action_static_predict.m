function result = action_static_predict(appState, params)
%ACTION_STATIC_PREDICT Train if needed, select one image, and run prediction.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    result = base_result("error", "单张识别未开始。");
    try
        [imageData, imagePath, canceled] = pick_test_image();
        if canceled
            result.status = "canceled";
            result.message = "已取消单张识别。";
            return;
        end

        model = ensure_recognition_model(appState, params);
        predictResult = predict_face_identity(model, imageData, struct());

        appState.model = model;
        appState.singleResult = predictResult;
        appState.currentImage = imageData;
        appState.currentImagePath = imagePath;
        if isfield(predictResult, 'alignedFace') && ~isempty(predictResult.alignedFace)
            appState.currentAlignedFace = predictResult.alignedFace;
        end

        result.status = get_status(predictResult);
        result.message = get_message(predictResult, "单张识别完成。");
        result.appState = appState;
        result.sourceImage = imageData;
        result.faceImage = get_field_or(predictResult, 'alignedFace', []);
        result.singleText = build_single_text(predictResult);
    catch ME
        result.status = "error";
        result.message = "单张识别失败: " + string(ME.message);
    end
end

function [img, imagePath, canceled] = pick_test_image()
    [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'});
    canceled = isequal(file, 0);
    img = [];
    imagePath = "";
    if canceled
        return;
    end
    imagePath = string(fullfile(path, file));
    img = imread(imagePath);
end

function textLines = build_single_text(predictResult)
    name = string(get_field_or(predictResult, 'name', ""));
    topKNames = get_field_or(predictResult, 'topKNames', {});
    topKScores = get_field_or(predictResult, 'topKScores', []);
    elapsedMs = get_field_or(predictResult, 'elapsedMs', []);

    if isempty(name)
        name = "-";
    end
    topKText = format_topk(topKNames, topKScores);
    elapsedText = "-";
    if ~isempty(elapsedMs)
        elapsedText = sprintf('%.2f ms', elapsedMs);
    end

    textLines = {
        char("预测姓名: " + name)
        char("Top-3: " + topKText)
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

function result = base_result(status, message)
    result = struct('status', status, 'message', message, 'appState', []);
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function status = get_status(s)
    status = string(get_field_or(s, 'status', "ok"));
end

function message = get_message(s, defaultMessage)
    message = string(get_field_or(s, 'message', defaultMessage));
end
