function assets = load_ui_assets(rootDir)
%LOAD_UI_ASSETS Resolve mascot image paths and create original defaults.

    if nargin < 1 || isempty(rootDir)
        rootDir = fileparts(fileparts(mfilename('fullpath')));
    end

    mascotDir = fullfile(rootDir, 'assets', 'mascot');
    if ~exist(mascotDir, 'dir')
        mkdir(mascotDir);
    end

    assets = struct();
    assets.mascotDir = mascotDir;
    assets.idle = ensure_mascot_file(mascotDir, 'idle.png', [0.86 0.94 1.00], 'idle');
    assets.loading = ensure_mascot_file(mascotDir, 'loading.png', [0.90 1.00 0.83], 'loading');
    assets.success = ensure_mascot_file(mascotDir, 'success.png', [1.00 0.93 0.70], 'success');
    assets.error = ensure_mascot_file(mascotDir, 'error.png', [1.00 0.82 0.86], 'error');
    assets.helper = ensure_mascot_file(mascotDir, 'helper.png', [0.94 0.90 1.00], 'helper');
    assets.leftCorner = ensure_mascot_file(mascotDir, 'left_corner.png', [0.68 0.92 0.67], 'idle');
    assets.rightCornerBlue = ensure_mascot_file(mascotDir, 'right_corner_blue.png', [0.86 0.94 1.00], 'helper');
    assets.preprocessWelcome = ensure_scene_file(mascotDir, 'preprocess_welcome.png', 'preprocess');
    assets.recognitionWelcome = ensure_scene_file(mascotDir, 'recognition_welcome.png', 'recognition');
    assets.cameraWelcome = ensure_scene_file(mascotDir, 'camera_welcome.png', 'camera');
    assets.resultWelcome = ensure_scene_file(mascotDir, 'result_welcome.png', 'result');
end

function path = ensure_mascot_file(mascotDir, fileName, bgColor, mood)
    path = fullfile(mascotDir, fileName);
    if exist(path, 'file')
        return;
    end

    img = make_mascot_bitmap(bgColor, mood);
    imwrite(img, path);
end

function path = ensure_scene_file(mascotDir, fileName, mood)
    path = fullfile(mascotDir, fileName);
    if exist(path, 'file')
        return;
    end

    img = make_scene_bitmap(mood);
    imwrite(img, path);
end

function img = make_mascot_bitmap(bgColor, mood)
    h = 180;
    w = 180;
    [x, y] = meshgrid(1:w, 1:h);
    img = ones(h, w, 3);
    for c = 1:3
        img(:, :, c) = bgColor(c);
    end

    body = ((x - 90) ./ 55) .^ 2 + ((y - 103) ./ 50) .^ 2 <= 1;
    head = ((x - 90) ./ 46) .^ 2 + ((y - 72) ./ 38) .^ 2 <= 1;
    leftEar = ((x - 57) ./ 15) .^ 2 + ((y - 46) ./ 23) .^ 2 <= 1;
    rightEar = ((x - 123) ./ 15) .^ 2 + ((y - 46) ./ 23) .^ 2 <= 1;
    mascot = body | head | leftEar | rightEar;
    outline = bwmorph(mascot, 'remove');

    img = paint_mask(img, mascot, [1 1 1]);
    img = paint_mask(img, outline, [0.16 0.18 0.19]);

    blushL = ((x - 58) ./ 10) .^ 2 + ((y - 85) ./ 5) .^ 2 <= 1;
    blushR = ((x - 122) ./ 10) .^ 2 + ((y - 85) ./ 5) .^ 2 <= 1;
    img = paint_mask(img, blushL | blushR, [1.00 0.67 0.73]);

    eyeL = ((x - 73) ./ 5) .^ 2 + ((y - 72) ./ 7) .^ 2 <= 1;
    eyeR = ((x - 107) ./ 5) .^ 2 + ((y - 72) ./ 7) .^ 2 <= 1;
    img = paint_mask(img, eyeL | eyeR, [0.10 0.11 0.12]);

    switch string(mood)
        case "loading"
            mouth = abs(((x - 90) ./ 18) .^ 2 + ((y - 94) ./ 9) .^ 2 - 1) < 0.08 & y > 90;
            hat = y > 33 & y < 48 & abs(x - 90) < 34;
            img = paint_mask(img, hat, [0.35 0.68 0.82]);
        case "success"
            mouth = abs(y - (96 - 0.18 .* (x - 90) .^ 2 ./ 6)) < 1.3 & x > 76 & x < 104;
            sparkle = abs(x - 137) < 2 & y > 43 & y < 72 | abs(y - 58) < 2 & x > 122 & x < 152;
            img = paint_mask(img, sparkle, [0.13 0.67 0.90]);
        case "error"
            mouth = abs(y - (88 + 0.16 .* (x - 90) .^ 2 ./ 5)) < 1.5 & x > 76 & x < 104;
            mark = abs(x - y - 36) < 2 & x > 126 & x < 151 | abs(x + y - 197) < 2 & x > 126 & x < 151;
            img = paint_mask(img, mark, [0.88 0.22 0.24]);
        case "helper"
            mouth = abs(y - (95 - 0.14 .* (x - 90) .^ 2 ./ 5)) < 1.3 & x > 77 & x < 103;
            qmark = ((x - 137) ./ 13) .^ 2 + ((y - 56) ./ 17) .^ 2 <= 1 & x > 137;
            img = paint_mask(img, qmark, [0.13 0.67 0.90]);
        otherwise
            mouth = abs(y - (95 - 0.12 .* (x - 90) .^ 2 ./ 5)) < 1.2 & x > 77 & x < 103;
    end

    img = paint_mask(img, mouth, [0.10 0.11 0.12]);
    img = im2uint8(img);
end

function img = make_scene_bitmap(mood)
    h = 360;
    w = 560;
    [x, y] = meshgrid(1:w, 1:h);
    img = ones(h, w, 3);

    base = [0.92 0.98 1.00];
    if mood == "recognition"
        base = [1.00 0.94 0.97];
    elseif mood == "camera"
        base = [0.93 1.00 0.88];
    elseif mood == "result"
        base = [1.00 0.97 0.85];
    end
    for c = 1:3
        img(:, :, c) = base(c);
    end

    wave1 = y > 250 + 18 .* sin(x ./ 45);
    wave2 = y > 288 + 13 .* sin(x ./ 31);
    img = paint_mask(img, wave1, [0.76 0.93 0.98]);
    img = paint_mask(img, wave2, [0.72 0.90 0.76]);

    cloud1 = ((x - 92) ./ 46) .^ 2 + ((y - 76) ./ 22) .^ 2 <= 1 | ...
        ((x - 130) ./ 58) .^ 2 + ((y - 70) ./ 26) .^ 2 <= 1 | ...
        ((x - 176) ./ 46) .^ 2 + ((y - 78) ./ 22) .^ 2 <= 1;
    cloud2 = ((x - 396) ./ 38) .^ 2 + ((y - 108) ./ 18) .^ 2 <= 1 | ...
        ((x - 432) ./ 50) .^ 2 + ((y - 101) ./ 24) .^ 2 <= 1 | ...
        ((x - 474) ./ 38) .^ 2 + ((y - 110) ./ 19) .^ 2 <= 1;
    img = paint_mask(img, cloud1 | cloud2, [1 1 1]);

    dots = mod(round(x ./ 34) + round(y ./ 34), 8) == 0 & ...
        (x < 150 | x > 410 | y < 88 | y > 292);
    img = paint_mask(img, dots, 0.86 .* base + 0.14 .* [0.22 0.68 0.88]);

    body = ((x - 282) ./ 82) .^ 2 + ((y - 194) ./ 70) .^ 2 <= 1;
    head = ((x - 282) ./ 68) .^ 2 + ((y - 145) ./ 56) .^ 2 <= 1;
    leftEar = ((x - 232) ./ 24) .^ 2 + ((y - 106) ./ 36) .^ 2 <= 1;
    rightEar = ((x - 332) ./ 24) .^ 2 + ((y - 106) ./ 36) .^ 2 <= 1;
    mascot = body | head | leftEar | rightEar;
    outline = bwmorph(mascot, 'remove');
    img = paint_mask(img, mascot, [1 1 1]);
    img = paint_mask(img, outline, [0.16 0.18 0.19]);

    eyeL = ((x - 258) ./ 7) .^ 2 + ((y - 146) ./ 10) .^ 2 <= 1;
    eyeR = ((x - 306) ./ 7) .^ 2 + ((y - 146) ./ 10) .^ 2 <= 1;
    blushL = ((x - 232) ./ 15) .^ 2 + ((y - 167) ./ 7) .^ 2 <= 1;
    blushR = ((x - 332) ./ 15) .^ 2 + ((y - 167) ./ 7) .^ 2 <= 1;
    mouth = abs(y - (179 - 0.10 .* (x - 282) .^ 2 ./ 4)) < 1.8 & x > 260 & x < 304;
    img = paint_mask(img, eyeL | eyeR | mouth, [0.10 0.11 0.12]);
    img = paint_mask(img, blushL | blushR, [1.00 0.67 0.73]);

    if mood == "preprocess"
        icon = abs(x - 103) < 6 & y > 180 & y < 258 | abs(y - 219) < 6 & x > 65 & x < 141;
        img = paint_mask(img, icon, [0.20 0.65 0.88]);
        tag = x > 380 & x < 486 & y > 180 & y < 238;
        img = paint_mask(img, tag, [1.00 0.88 0.48]);
    elseif mood == "recognition"
        lens = ((x - 120) ./ 42) .^ 2 + ((y - 214) ./ 42) .^ 2 <= 1;
        handle = abs(y - (245 + 0.65 .* (x - 150))) < 5 & x > 145 & x < 196;
        img = paint_mask(img, lens | handle, [0.23 0.68 0.88]);
    elseif mood == "camera"
        cam = x > 76 & x < 176 & y > 190 & y < 254;
        lens = ((x - 126) ./ 24) .^ 2 + ((y - 222) ./ 24) .^ 2 <= 1;
        img = paint_mask(img, cam, [0.35 0.69 0.82]);
        img = paint_mask(img, lens, [1 1 1]);
    else
        star = abs(x - 106) < 5 & y > 180 & y < 260 | abs(y - 220) < 5 & x > 66 & x < 146 | ...
            abs((y - 220) - (x - 106)) < 4 & x > 76 & x < 136 | ...
            abs((y - 220) + (x - 106)) < 4 & x > 76 & x < 136;
        img = paint_mask(img, star, [0.95 0.62 0.16]);
    end

    img = im2uint8(img);
end

function img = paint_mask(img, mask, color)
    for c = 1:3
        layer = img(:, :, c);
        layer(mask) = color(c);
        img(:, :, c) = layer;
    end
end
