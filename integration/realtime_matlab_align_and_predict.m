function result = realtime_matlab_align_and_predict(model, frame, options)
%REALTIME_MATLAB_ALIGN_AND_PREDICT Align one frame and predict in MATLAB only.

    if nargin < 3 || isempty(options)
        options = struct();
    end

    timerHandle = tic;
    alignOptions = struct();
    alignOptions.imageSize = get_option(options, 'imageSize', [112, 92]);
    alignOptions.detectorMode = get_option(options, 'detectorMode', 'robust');
    alignOptions.useEqualizedSearch = get_option(options, 'useEqualizedSearch', true);
    alignOptions.minFaceRatio = get_option(options, 'minFaceRatio', 0.68);
    alignOptions.facePadding = get_option(options, 'facePadding', 0.18);

    try
        faceInfo = detect_face(frame, alignOptions);
        faceInfo = trim_face_box(faceInfo, frame);
        alignInfo = align_face(frame, faceInfo, alignOptions);
        alignedFace = alignInfo.alignedFace;
        faceBox = faceInfo.faceBox;
        alignStatus = sprintf('%s | %s', faceInfo.message, alignInfo.message);
    catch err
        input = preprocess_for_model(frame, struct('imageSize', alignOptions.imageSize));
        alignedFace = input.image;
        faceBox = center_square_box(size(frame), 0.72);
        alignStatus = ['fallback: ', err.message];
    end

    pred = predict_face_identity(model, alignedFace, options);

    result = struct();
    result.status = pred.status;
    result.message = pred.message;
    result.name = pred.name;
    result.topKNames = pred.topKNames;
    result.topKScores = pred.topKScores;
    result.faceBox = faceBox;
    result.alignedFace = alignedFace;
    result.alignStatus = alignStatus;
    result.alignAndPredictMs = toc(timerHandle) * 1000;
    result.predElapsedMs = pred.elapsedMs;
end

function faceInfo = trim_face_box(faceInfo, frame)
    if isempty(faceInfo) || ~isfield(faceInfo, 'faceBox') || isempty(faceInfo.faceBox)
        return;
    end

    box = faceInfo.faceBox;
    imgH = size(frame, 1);
    imgW = size(frame, 2);
    faceTop = max(1, round(box(2) + box(4) * 0.10));
    faceLeft = max(1, round(box(1) + box(3) * 0.10));
    faceRight = min(imgW, round(box(1) + box(3) * 0.90));
    faceBottom = min(imgH, round(box(2) + box(4) * 0.82));
    faceInfo.faceBox = [faceLeft, faceTop, max(1, faceRight - faceLeft + 1), max(1, faceBottom - faceTop + 1)];
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function box = center_square_box(imageSize, ratio)
    imgH = imageSize(1);
    imgW = imageSize(2);
    side = round(min(imgH, imgW) * ratio);
    x = round((imgW - side) / 2) + 1;
    y = round((imgH - side) / 2) + 1;
    box = [x, y, side, side];
end
