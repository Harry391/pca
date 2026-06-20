function faceInfo = detect_face(img, options)
%DETECT_FACE MATLAB-only face detection plus landmark estimation.
%
% The face box still uses MATLAB's built-in cascade detector. Landmarks are
% estimated inside the face crop with image cues, avoiding unreliable
% left-eye/right-eye/mouth cascade hits.

    if nargin < 2 || isempty(options)
        options = struct();
    end

    minFaceRatio = get_option(options, 'minFaceRatio', 0.68);
    useEqualizedSearch = get_option(options, 'useEqualizedSearch', true);
    facePadding = get_option(options, 'facePadding', 0.32);
    detectorMode = get_option(options, 'detectorMode', 'robust');
    innerFaceTrim = get_option(options, 'innerFaceTrim', [0.10, 0.18, 0.10, 0.08]);

    faceInfo = struct();
    faceInfo.status = 'error';
    faceInfo.faceBox = [];
    faceInfo.faceImage = [];
    faceInfo.faceColorImage = [];
    faceInfo.landmarks = struct();
    faceInfo.message = '';

    if nargin < 1 || isempty(img)
        faceInfo.status = 'empty_input';
        faceInfo.message = '没有可检测的图像。';
        return;
    end

    try
    gray = convert_to_gray(img);
    gray = im2uint8_local(gray);
    color = ensure_rgb(img);

    bestBox = detect_best_face_box(gray, useEqualizedSearch, detectorMode);
    if isempty(bestBox)
        bestBox = center_square_box(size(gray), minFaceRatio);
        faceMessage = 'fallback center crop';
    else
        faceMessage = 'detected face';
    end

    faceBox = expand_square_box(bestBox, size(gray), facePadding);
    faceBox = clamp_square_box(faceBox, size(gray));
    faceBox = shrink_to_inner_face(faceBox, size(gray), innerFaceTrim);
    faceGray = crop_box(gray, faceBox);
    faceColor = crop_box(color, faceBox);
    landmarks = estimate_landmarks(faceColor, faceGray);

    faceInfo.status = 'ok';
    faceInfo.faceBox = faceBox;
    faceInfo.faceImage = faceGray;
    faceInfo.faceColorImage = faceColor;
    faceInfo.landmarks = landmarks;
    faceInfo.message = sprintf('%s | %s', faceMessage, landmarks.message);
    catch ME
        faceInfo.status = 'error';
        faceInfo.message = ['人脸检测失败: ', ME.message];
    end
end

function box = shrink_to_inner_face(box, imageSize, trim)
    if numel(trim) ~= 4
        return;
    end

    leftTrim = trim(1);
    topTrim = trim(2);
    rightTrim = trim(3);
    bottomTrim = trim(4);

    x1 = box(1) + round(box(3) * leftTrim);
    y1 = box(2) + round(box(4) * topTrim);
    x2 = box(1) + box(3) - 1 - round(box(3) * rightTrim);
    y2 = box(2) + box(4) - 1 - round(box(4) * bottomTrim);

    if x2 <= x1 + 20 || y2 <= y1 + 20
        return;
    end

    box = clamp_rect([x1, y1, x2 - x1 + 1, y2 - y1 + 1], imageSize);
end

function bestBox = detect_best_face_box(gray, useEqualizedSearch, detectorMode)
    boxes = [];
    if exist('vision.CascadeObjectDetector', 'class') == 8
        persistent frontalCart frontalLbp
        if isempty(frontalCart)
            frontalCart = vision.CascadeObjectDetector('FrontalFaceCART');
            frontalCart.MergeThreshold = 3;
        end
        if isempty(frontalLbp)
            frontalLbp = vision.CascadeObjectDetector('FrontalFaceLBP');
            frontalLbp.MergeThreshold = 3;
        end

        boxes = [boxes; step(frontalCart, gray)]; %#ok<AGROW>
        if ~strcmpi(detectorMode, 'fast')
            boxes = [boxes; step(frontalLbp, gray)]; %#ok<AGROW>
        end
        if useEqualizedSearch && ~strcmpi(detectorMode, 'fast')
            boxes = [boxes; step(frontalCart, histeq(gray))]; %#ok<AGROW>
        end
    end

    bestBox = [];
    if isempty(boxes)
        return;
    end

    boxes = dedupe_boxes(boxes);
    [imgH, imgW] = size(gray);
    areas = boxes(:, 3) .* boxes(:, 4);
    centerX = boxes(:, 1) + boxes(:, 3) / 2;
    centerY = boxes(:, 2) + boxes(:, 4) / 2;
    areaScore = areas / max(1, imgH * imgW);
    centerPenalty = ((centerX - imgW / 2) / imgW) .^ 2 + 1.5 * ((centerY - imgH * 0.46) / imgH) .^ 2;
    sizePenalty = max(0, 0.12 - areaScore);
    score = areaScore - 0.85 * centerPenalty - 0.45 * sizePenalty;
    [~, index] = max(score);
    bestBox = boxes(index, :);
end

function boxes = dedupe_boxes(boxes)
    if size(boxes, 1) <= 1
        return;
    end

    keep = true(size(boxes, 1), 1);
    for i = 1:size(boxes, 1)
        if ~keep(i)
            continue;
        end
        for j = i + 1:size(boxes, 1)
            if ~keep(j)
                continue;
            end
            if box_iou(boxes(i, :), boxes(j, :)) > 0.55
                areaI = boxes(i, 3) * boxes(i, 4);
                areaJ = boxes(j, 3) * boxes(j, 4);
                if areaI >= areaJ
                    keep(j) = false;
                else
                    keep(i) = false;
                    break;
                end
            end
        end
    end
    boxes = boxes(keep, :);
end

function value = box_iou(a, b)
    ax2 = a(1) + a(3) - 1;
    ay2 = a(2) + a(4) - 1;
    bx2 = b(1) + b(3) - 1;
    by2 = b(2) + b(4) - 1;

    ix1 = max(a(1), b(1));
    iy1 = max(a(2), b(2));
    ix2 = min(ax2, bx2);
    iy2 = min(ay2, by2);

    iw = max(0, ix2 - ix1 + 1);
    ih = max(0, iy2 - iy1 + 1);
    inter = iw * ih;
    unionArea = a(3) * a(4) + b(3) * b(4) - inter;
    value = inter / max(1, unionArea);
end

function landmarks = estimate_landmarks(faceColor, faceGray)
    analysisSize = [240, 240];
    gray = im2double_local(faceGray);
    color = im2double_local(faceColor);
    grayN = imresize(gray, analysisSize, 'bilinear');
    colorN = imresize(color, analysisSize, 'bilinear');
    [h, w] = size(grayN);

    eyeBand = detect_eye_pair_band(grayN);
    leftRegion = [eyeBand(1), eyeBand(2), floor(eyeBand(3) / 2), eyeBand(4)];
    rightRegion = [eyeBand(1) + ceil(eyeBand(3) / 2), eyeBand(2), floor(eyeBand(3) / 2), eyeBand(4)];

    leftEye = locate_eye(grayN, leftRegion, [w * 0.33, h * 0.38]);
    rightEye = locate_eye(grayN, rightRegion, [w * 0.67, h * 0.38]);
    mouth = locate_mouth(grayN, colorN, [round(w * 0.24), round(h * 0.56), round(w * 0.52), round(h * 0.24)]);

    [leftEye, rightEye, mouth, method] = enforce_geometry(leftEye, rightEye, mouth, w, h);

    scaleX = size(faceGray, 2) / w;
    scaleY = size(faceGray, 1) / h;
    landmarks = struct();
    landmarks.leftEye = [leftEye(1) * scaleX, leftEye(2) * scaleY];
    landmarks.rightEye = [rightEye(1) * scaleX, rightEye(2) * scaleY];
    landmarks.mouth = [mouth(1) * scaleX, mouth(2) * scaleY];
    landmarks.eyeBand = [eyeBand(1) * scaleX, eyeBand(2) * scaleY, eyeBand(3) * scaleX, eyeBand(4) * scaleY];
    landmarks.message = method;
end

function eyeBand = detect_eye_pair_band(grayN)
    [h, w] = size(grayN);
    eyeBand = [round(w * 0.16), round(h * 0.22), round(w * 0.68), round(h * 0.24)];

    if exist('vision.CascadeObjectDetector', 'class') ~= 8
        return;
    end

    persistent eyePairDetector
    if isempty(eyePairDetector)
        eyePairDetector = vision.CascadeObjectDetector('EyePairBig');
        eyePairDetector.MergeThreshold = 5;
    end

    try
        boxes = step(eyePairDetector, im2uint8_local(grayN));
    catch
        boxes = [];
    end
    if isempty(boxes)
        return;
    end

    keep = boxes(:, 2) > h * 0.12 & boxes(:, 2) < h * 0.52 & ...
        boxes(:, 3) > w * 0.24 & boxes(:, 3) < w * 0.82;
    boxes = boxes(keep, :);
    if isempty(boxes)
        return;
    end

    expected = [w * 0.16, h * 0.22, w * 0.68, h * 0.24];
    centers = [boxes(:, 1) + boxes(:, 3) / 2, boxes(:, 2) + boxes(:, 4) / 2];
    expectedCenter = [expected(1) + expected(3) / 2, expected(2) + expected(4) / 2];
    centerPenalty = sum((centers - expectedCenter) .^ 2, 2) / (w * h);
    areaScore = boxes(:, 3) .* boxes(:, 4) / (w * h);
    [~, index] = max(areaScore - 0.4 * centerPenalty);
    box = boxes(index, :);
    eyeBand = expand_rect(box, [h, w], 0.16, 0.38);
end

function point = locate_eye(grayN, region, defaultPoint)
    region = clamp_rect(region, size(grayN));
    patch = grayN(region(2):region(2) + region(4) - 1, region(1):region(1) + region(3) - 1);
    patch = local_equalize(patch);
    grad = gradient_magnitude(patch);
    dark = 1 - patch;

    [ph, pw] = size(patch);
    [xGrid, yGrid] = meshgrid(1:pw, 1:ph);
    prior = gaussian_prior(xGrid, yGrid, pw * 0.50, ph * 0.55, pw * 0.30, ph * 0.24);
    score = (0.68 * normalize01(dark) + 0.32 * normalize01(grad)) .* prior;

    localPoint = weighted_top_centroid(score, 92, [pw * 0.50, ph * 0.55]);
    point = [region(1) + localPoint(1) - 1, region(2) + localPoint(2) - 1];

    if any(~isfinite(point))
        point = defaultPoint;
    end
end

function point = locate_mouth(grayN, colorN, region)
    region = clamp_rect(region, size(grayN));
    grayPatch = grayN(region(2):region(2) + region(4) - 1, region(1):region(1) + region(3) - 1);
    colorPatch = colorN(region(2):region(2) + region(4) - 1, region(1):region(1) + region(3) - 1, :);

    grayPatch = local_equalize(grayPatch);
    verticalEdge = abs(conv2(grayPatch, [-1 -2 -1; 0 0 0; 1 2 1], 'same'));
    dark = 1 - grayPatch;
    red = max(0, colorPatch(:, :, 1) - 0.45 * colorPatch(:, :, 2) - 0.45 * colorPatch(:, :, 3));

    [ph, pw] = size(grayPatch);
    [xGrid, yGrid] = meshgrid(1:pw, 1:ph);
    prior = gaussian_prior(xGrid, yGrid, pw * 0.50, ph * 0.52, pw * 0.28, ph * 0.26);
    score = (0.36 * normalize01(dark) + 0.34 * normalize01(red) + 0.30 * normalize01(verticalEdge)) .* prior;

    localPoint = weighted_top_centroid(score, 90, [pw * 0.50, ph * 0.52]);
    point = [region(1) + localPoint(1) - 1, region(2) + localPoint(2) - 1];
end

function [leftEye, rightEye, mouth, method] = enforce_geometry(leftEye, rightEye, mouth, w, h)
    method = 'landmark-score';
    eyeDist = rightEye(1) - leftEye(1);
    eyeYGap = abs(rightEye(2) - leftEye(2));

    if eyeDist < w * 0.20 || eyeDist > w * 0.58 || eyeYGap > h * 0.13
        leftEye = [w * 0.33, h * 0.38];
        rightEye = [w * 0.67, h * 0.38];
        method = 'template-eyes';
    end

    eyeCenterY = (leftEye(2) + rightEye(2)) / 2;
    if mouth(2) < eyeCenterY + h * 0.18 || mouth(2) > h * 0.88 || mouth(1) < w * 0.20 || mouth(1) > w * 0.80
        mouth = [w * 0.50, h * 0.72];
        method = [method '+template-mouth'];
    end
end

function rect = expand_rect(rect, imageSize, padX, padY)
    x = rect(1);
    y = rect(2);
    rw = rect(3);
    rh = rect(4);
    cx = x + rw / 2;
    cy = y + rh / 2;
    newW = rw * (1 + 2 * padX);
    newH = rh * (1 + 2 * padY);
    rect = [round(cx - newW / 2), round(cy - newH / 2), round(newW), round(newH)];
    rect = clamp_rect(rect, imageSize);
end

function rect = clamp_rect(rect, imageSize)
    h = imageSize(1);
    w = imageSize(2);
    x = max(1, min(w, round(rect(1))));
    y = max(1, min(h, round(rect(2))));
    rw = max(1, round(rect(3)));
    rh = max(1, round(rect(4)));
    rw = min(rw, w - x + 1);
    rh = min(rh, h - y + 1);
    rect = [x, y, rw, rh];
end

function prior = gaussian_prior(xGrid, yGrid, cx, cy, sx, sy)
    prior = exp(-((xGrid - cx) .^ 2) / (2 * sx ^ 2) - ((yGrid - cy) .^ 2) / (2 * sy ^ 2));
end

function point = weighted_top_centroid(score, percentileValue, defaultPoint)
    threshold = percentile_local(score(:), percentileValue);
    weights = score;
    weights(weights < threshold) = 0;
    weightSum = sum(weights(:));
    if weightSum <= eps
        point = defaultPoint;
        return;
    end

    [h, w] = size(score);
    [xGrid, yGrid] = meshgrid(1:w, 1:h);
    point = [sum(sum(weights .* xGrid)) / weightSum, sum(sum(weights .* yGrid)) / weightSum];
end

function out = gradient_magnitude(img)
    gx = conv2(img, [-1 0 1; -2 0 2; -1 0 1], 'same');
    gy = conv2(img, [-1 -2 -1; 0 0 0; 1 2 1], 'same');
    out = sqrt(gx .^ 2 + gy .^ 2);
end

function out = local_equalize(img)
    if exist('adapthisteq', 'file') == 2
        out = adapthisteq(img, 'ClipLimit', 0.02, 'NumTiles', [4 4]);
    else
        out = histeq(im2uint8_local(img));
        out = im2double_local(out);
    end
end

function out = normalize01(img)
    img = double(img);
    minValue = min(img(:));
    maxValue = max(img(:));
    if maxValue <= minValue
        out = zeros(size(img));
    else
        out = (img - minValue) / (maxValue - minValue);
    end
end

function value = percentile_local(values, percentileValue)
    values = sort(values(:));
    index = max(1, min(numel(values), round(percentileValue / 100 * numel(values))));
    value = values(index);
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function out = im2uint8_local(img)
    img = double(img);
    if max(img(:)) <= 1
        img = img * 255;
    end
    out = uint8(min(max(round(img), 0), 255));
end

function out = im2double_local(img)
    out = double(img);
    if max(out(:)) > 1
        out = out / 255;
    end
    out = min(max(out, 0), 1);
end

function color = ensure_rgb(img)
    if ndims(img) == 2
        color = repmat(img, 1, 1, 3);
    else
        color = img(:, :, 1:3);
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
    side = round(side);
    x1 = max(1, min(imgW - side + 1, x1));
    y1 = max(1, min(imgH - side + 1, y1));
    side = min([side, imgW - x1 + 1, imgH - y1 + 1]);
    box = [x1, y1, side, side];
end

function box = clamp_square_box(box, imageSize)
    x = round(box(1));
    y = round(box(2));
    side = round(max(box(3), box(4)));
    imgH = imageSize(1);
    imgW = imageSize(2);
    x = max(1, min(imgW - side + 1, x));
    y = max(1, min(imgH - side + 1, y));
    side = min([side, imgW - x + 1, imgH - y + 1]);
    box = [x, y, side, side];
end

function crop = crop_box(img, box)
    x = box(1);
    y = box(2);
    w = box(3);
    h = box(4);
    crop = img(y:y + h - 1, x:x + w - 1, :);
end
