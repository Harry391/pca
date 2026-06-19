function alignInfo = align_face_from_points(img, points, targetSize)
%ALIGN_FACE_FROM_POINTS Align a face from left-eye/right-eye/mouth points.
%
% points order: left eye, right eye, mouth. Coordinates are in the source
% image coordinate system.

    if nargin < 3 || isempty(targetSize)
        targetSize = [112, 92];
    end

    points = double(points);
    if size(points, 1) ~= 3 || size(points, 2) ~= 2 || any(~isfinite(points(:)))
        error('align_face_from_points:InvalidPoints', 'points must be a finite 3x2 matrix.');
    end

    rgb = ensure_rgb(im2double_local(img));
    pad = max(20, round(max(size(rgb, 1), size(rgb, 2)) * 0.45));
    padded = reflect_pad(rgb, pad);

    srcPoints = points + pad;
    dstPoints = canonical_points(targetSize);
    transform = fit_affine_transform(srcPoints, dstPoints);

    outputRef = imref2d(targetSize);
    alignedColor = imwarp(padded, transform, 'OutputView', outputRef, 'FillValues', 0);
    alignedGray = convert_to_gray(alignedColor);
    alignedGray = normalize_gray(alignedGray);

    alignInfo = struct();
    alignInfo.status = 'ok';
    alignInfo.message = 'manual 3-point aligned';
    alignInfo.alignedFace = alignedGray;
    alignInfo.srcPoints = points;
    alignInfo.dstPoints = dstPoints;
    alignInfo.targetSize = targetSize;
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

function transform = fit_affine_transform(srcPoints, dstPoints)
    if exist('fitgeotform2d', 'file') == 2
        transform = fitgeotform2d(srcPoints, dstPoints, 'affine');
    else
        transform = fitgeotrans(srcPoints, dstPoints, 'affine');
    end
end

function rgb = ensure_rgb(img)
    if ndims(img) == 2
        rgb = repmat(img, 1, 1, 3);
    else
        rgb = img(:, :, 1:3);
    end
end

function out = im2double_local(img)
    out = double(img);
    if max(out(:)) > 1
        if isa(img, 'uint16')
            out = out / 65535;
        else
            out = out / 255;
        end
    end
    out = min(max(out, 0), 1);
end

function padded = reflect_pad(img, pad)
    if exist('padarray', 'file') == 2
        padded = padarray(img, [pad, pad], 'symmetric', 'both');
        return;
    end

    rowIdx = reflect_indices(1 - pad:size(img, 1) + pad, size(img, 1));
    colIdx = reflect_indices(1 - pad:size(img, 2) + pad, size(img, 2));
    padded = img(rowIdx, colIdx, :);
end

function idx = reflect_indices(idx, n)
    period = 2 * n;
    idx = mod(idx - 1, period) + 1;
    over = idx > n;
    idx(over) = period - idx(over) + 1;
end

function out = normalize_gray(img)
    img = im2double_local(img);
    if exist('adapthisteq', 'file') == 2
        out = adapthisteq(img, 'ClipLimit', 0.02, 'NumTiles', [8, 8]);
    else
        out = histeq(im2uint8(img));
        out = im2double(out);
    end
end
