function alignInfo = align_face(img, faceInfo, options)
%ALIGN_FACE MATLAB-only 3-point affine alignment.
%
% This mirrors the landmark runtime path structurally: left eye, right eye
% and mouth are mapped to fixed target locations, then converted to
% normalized grayscale.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    if nargin < 2
        faceInfo = struct();
    end

    targetSize = get_option(options, 'imageSize', [112, 92]);
    alignInfo = struct();
    alignInfo.status = 'error';
    alignInfo.alignedFace = [];
    alignInfo.transformInfo = struct();
    alignInfo.message = '';

    if (nargin < 2 || isempty(faceInfo) || ~isstruct(faceInfo) || ...
            ~isfield(faceInfo, 'faceImage') || isempty(faceInfo.faceImage)) && ...
            (nargin < 1 || isempty(img))
        alignInfo.status = 'empty_input';
        alignInfo.message = '没有可校准的人脸图像。';
        return;
    end

    try
    if isempty(faceInfo) || ~isstruct(faceInfo) || ~isfield(faceInfo, 'faceImage') || isempty(faceInfo.faceImage)
        faceInfo = detect_face(img, options);
    end

    if isfield(faceInfo, 'faceColorImage') && ~isempty(faceInfo.faceColorImage)
        faceImg = im2double_local(faceInfo.faceColorImage);
    else
        faceImg = im2double_local(ensure_rgb(faceInfo.faceImage));
    end

    landmarks = sanitize_landmarks(faceInfo.landmarks, size(faceImg));
    srcPoints = [
        landmarks.leftEye;
        landmarks.rightEye;
        landmarks.mouth
    ];
    dstPoints = canonical_points(targetSize);

    pad = max(20, round(max(size(faceImg, 1), size(faceImg, 2)) * 0.45));
    paddedFace = symmetric_pad(faceImg, pad);
    paddedSrcPoints = srcPoints + pad;

    transform = fitgeotform2d(paddedSrcPoints, dstPoints, 'affine');
    ref = imref2d(targetSize);
    alignedColor = imwarp(paddedFace, transform, 'OutputView', ref, 'FillValues', 0);
    alignedGray = convert_to_gray(alignedColor);
    alignedGray = clahe_local(alignedGray);

    alignInfo.status = 'ok';
    alignInfo.alignedFace = alignedGray;
    alignInfo.transformInfo = struct( ...
        'method', 'affine-3point-matlab-landmarks', ...
        'targetSize', targetSize, ...
        'srcPoints', srcPoints, ...
        'dstPoints', dstPoints);
    alignInfo.message = 'aligned by MATLAB 3-point affine';
    catch ME
        alignInfo.status = 'error';
        alignInfo.message = ['人脸校准失败: ', ME.message];
    end
end

function landmarks = sanitize_landmarks(landmarks, imageSize)
    h = imageSize(1);
    w = imageSize(2);
    fallback = struct( ...
        'leftEye', [w * 0.32, h * 0.38], ...
        'rightEye', [w * 0.68, h * 0.38], ...
        'mouth', [w * 0.50, h * 0.72]);

    if ~isstruct(landmarks) || ~isfield(landmarks, 'leftEye') || ...
            ~isfield(landmarks, 'rightEye') || ~isfield(landmarks, 'mouth')
        landmarks = fallback;
        return;
    end

    landmarks.leftEye = clamp_point(double(landmarks.leftEye), w, h, fallback.leftEye);
    landmarks.rightEye = clamp_point(double(landmarks.rightEye), w, h, fallback.rightEye);
    landmarks.mouth = clamp_point(double(landmarks.mouth), w, h, fallback.mouth);

    eyeDist = landmarks.rightEye(1) - landmarks.leftEye(1);
    eyeYGap = abs(landmarks.rightEye(2) - landmarks.leftEye(2));
    eyeMidY = (landmarks.leftEye(2) + landmarks.rightEye(2)) / 2;
    if eyeDist < w * 0.18 || eyeDist > w * 0.64 || eyeYGap > h * 0.16 || landmarks.mouth(2) < eyeMidY + h * 0.15
        landmarks = fallback;
    end
end

function point = clamp_point(point, w, h, fallback)
    if numel(point) ~= 2 || any(~isfinite(point))
        point = fallback;
        return;
    end
    point = [min(max(point(1), 1), w), min(max(point(2), 1), h)];
end

function points = canonical_points(targetSize)
    h = targetSize(1);
    w = targetSize(2);
    points = [
        w * 0.32, h * 0.38;
        w * 0.68, h * 0.38;
        w * 0.50, h * 0.72
    ];
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
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

function padded = symmetric_pad(img, pad)
    [h, w, c] = size(img);
    padded = zeros(h + 2 * pad, w + 2 * pad, c, 'like', img);
    padded(pad + 1:pad + h, pad + 1:pad + w, :) = img;

    padded(1:pad, pad + 1:pad + w, :) = img(pad_index(pad:-1:1, h), :, :);
    padded(pad + h + 1:end, pad + 1:pad + w, :) = img(pad_index(h:-1:h - pad + 1, h), :, :);
    padded(:, 1:pad, :) = padded(:, 2 * pad:-1:pad + 1, :);
    padded(:, pad + w + 1:end, :) = padded(:, pad + w:-1:w + 1, :);
end

function index = pad_index(index, maxIndex)
    index = mod(index - 1, maxIndex) + 1;
end

function out = clahe_local(img)
    img = im2double_local(img);
    if exist('adapthisteq', 'file') == 2
        out = adapthisteq(img, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
    else
        out = histeq(im2uint8(img));
        out = im2double(out);
    end
end
