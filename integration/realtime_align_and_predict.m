function result = realtime_align_and_predict(rootDir, model, frame, options)
%REALTIME_ALIGN_AND_PREDICT Align one MATLAB-captured frame, then predict.

    if nargin < 4 || isempty(options)
        options = struct();
    end

    tempDir = fullfile(rootDir, 'results', 'realtime_temp');
    if ~isfolder(tempDir)
        mkdir(tempDir);
    end

    framePath = fullfile(tempDir, 'current_frame.jpg');
    alignedPath = fullfile(tempDir, 'current_aligned.jpg');
    imwrite(frame, framePath);

    add_runtime_services(rootDir);
    [alignedImage, alignStatus, alignmentLog] = runtime_align_single_face( ...
        rootDir, framePath, alignedPath, model.imageSize);

    if isempty(alignedImage)
        input = preprocess_for_model(frame, struct('imageSize', model.imageSize));
        pred = predict_face_identity(model, input.image, options);
        alignStatus = 'fallback_preprocess_only';
        alignedImage = input.image;
        faceBox = center_square_box(size(frame), 0.72);
    else
        pred = predict_face_identity(model, alignedImage, options);
        faceBox = detect_face_box_fallback(frame);
    end

    result = struct();
    result.status = pred.status;
    result.message = pred.message;
    result.name = pred.name;
    result.topKNames = pred.topKNames;
    result.topKScores = pred.topKScores;
    result.faceBox = faceBox;
    result.alignedFace = alignedImage;
    result.elapsedMs = pred.elapsedMs;
    result.alignStatus = alignStatus;
    result.alignmentLog = alignmentLog;
end

function box = detect_face_box_fallback(frame)
    box = center_square_box(size(frame), 0.72);
    if exist('vision.CascadeObjectDetector', 'class') ~= 8
        return;
    end

    detector = vision.CascadeObjectDetector('FrontalFaceCART');
    detector.MergeThreshold = 4;
    boxes = step(detector, frame);
    if isempty(boxes)
        return;
    end

    areas = boxes(:, 3) .* boxes(:, 4);
    [~, idx] = max(areas);
    box = expand_square_box(boxes(idx, :), size(frame), 0.35);
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
