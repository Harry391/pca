function faceInfo = detect_face(img, options)
%DETECT_FACE Detect the largest frontal face and crop it for downstream use.

    if nargin < 2 || isempty(options)
        options = struct();
    end

    faceInfo = struct( ...
        'status', "error", ...
        'faceBox', [], ...
        'faceImage', [], ...
        'landmarks', [], ...
        'message', "未开始检测");

    if nargin < 1 || isempty(img)
        faceInfo.status = "empty_input";
        faceInfo.message = "没有可检测的图像。";
        return;
    end

    try
        if exist('vision.CascadeObjectDetector', 'class') ~= 8
            faceInfo.status = "unavailable";
            faceInfo.message = "未检测到 Computer Vision Toolbox，无法使用 CascadeObjectDetector。";
            return;
        end

        detector = vision.CascadeObjectDetector();
        if isfield(options, 'MinSize') && ~isempty(options.MinSize)
            detector.MinSize = options.MinSize;
        end
        if isfield(options, 'MergeThreshold') && ~isempty(options.MergeThreshold)
            detector.MergeThreshold = options.MergeThreshold;
        end

        boxes = detector(img);
        if isempty(boxes)
            faceInfo.status = "no_face";
            faceInfo.message = "未检测到人脸。";
            return;
        end

        areas = boxes(:, 3) .* boxes(:, 4);
        [~, idx] = max(areas);
        box = round(boxes(idx, :));
        box = clamp_box(box, size(img));

        faceInfo.status = "ok";
        faceInfo.faceBox = box;
        faceInfo.faceImage = imcrop(img, box);
        faceInfo.landmarks = [];
        faceInfo.message = "已检测并裁剪最大人脸。";
    catch ME
        faceInfo.status = "error";
        faceInfo.message = "人脸检测失败: " + string(ME.message);
    end
end

function box = clamp_box(box, imgSize)
    width = imgSize(2);
    height = imgSize(1);

    x = max(1, min(box(1), width));
    y = max(1, min(box(2), height));
    w = max(1, min(box(3), width - x + 1));
    h = max(1, min(box(4), height - y + 1));
    box = [x, y, w, h];
end
