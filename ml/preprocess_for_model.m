function modelInput = preprocess_for_model(imageData, options)
%PREPROCESS_FOR_MODEL Normalize image input before hand-written PCA/SVM.

    if nargin < 2 || isempty(options)
        options = struct();
    end

    imageSize = get_option(options, 'imageSize', [112, 92]);
    useHistogramEqualization = get_option(options, 'useHistogramEqualization', false);

    if ischar(imageData) || isstring(imageData)
        imagePath = char(imageData);
        img = imread(imagePath);
    else
        imagePath = '';
        img = imageData;
    end

    if isempty(img)
        error('preprocess_for_model:EmptyImage', 'imageData is empty');
    end

    if ndims(img) == 3
        gray = rgb_to_gray(img);
    else
        gray = img;
    end

    gray = im2double_local(gray);
    gray = resize_bilinear(gray, imageSize(1), imageSize(2));

    if useHistogramEqualization
        gray = hist_equalize_local(gray);
    end

    vector = reshape(gray, 1, []);

    modelInput = struct();
    modelInput.status = 'ok';
    modelInput.message = 'image preprocessed';
    modelInput.image = gray;
    modelInput.vector = vector;
    modelInput.imageSize = imageSize;
    modelInput.imagePath = imagePath;
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function gray = rgb_to_gray(img)
    img = im2double_local(img);
    gray = 0.2989 * img(:, :, 1) + 0.5870 * img(:, :, 2) + 0.1140 * img(:, :, 3);
end

function out = im2double_local(img)
    if isa(img, 'double')
        out = img;
        if max(out(:)) > 1
            out = out / 255;
        end
    elseif isa(img, 'single')
        out = double(img);
        if max(out(:)) > 1
            out = out / 255;
        end
    elseif isa(img, 'uint8')
        out = double(img) / 255;
    elseif isa(img, 'uint16')
        out = double(img) / 65535;
    else
        out = double(img);
        if max(out(:)) > 1
            out = out / max(out(:));
        end
    end
    out = min(max(out, 0), 1);
end

function out = resize_bilinear(img, targetH, targetW)
    [srcH, srcW] = size(img);
    if srcH == targetH && srcW == targetW
        out = img;
        return;
    end

    y = linspace(1, srcH, targetH);
    x = linspace(1, srcW, targetW);
    [xGrid, yGrid] = meshgrid(x, y);

    x1 = floor(xGrid);
    y1 = floor(yGrid);
    x2 = min(x1 + 1, srcW);
    y2 = min(y1 + 1, srcH);
    x1 = max(x1, 1);
    y1 = max(y1, 1);

    dx = xGrid - x1;
    dy = yGrid - y1;

    idx11 = sub2ind([srcH, srcW], y1, x1);
    idx12 = sub2ind([srcH, srcW], y1, x2);
    idx21 = sub2ind([srcH, srcW], y2, x1);
    idx22 = sub2ind([srcH, srcW], y2, x2);

    out = (1 - dx) .* (1 - dy) .* img(idx11) + ...
        dx .* (1 - dy) .* img(idx12) + ...
        (1 - dx) .* dy .* img(idx21) + ...
        dx .* dy .* img(idx22);
end

function out = hist_equalize_local(img)
    bins = 256;
    values = min(max(round(img * (bins - 1)) + 1, 1), bins);
    counts = accumarray(values(:), 1, [bins, 1]);
    cdf = cumsum(counts) / numel(img);
    out = reshape(cdf(values), size(img));
end
