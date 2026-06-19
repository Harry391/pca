function simResult = run_raw_image_realtime_simulation(rawDir, maxImages, useAlignedManifest, splitFilter)
%RUN_RAW_IMAGE_REALTIME_SIMULATION Simulate realtime recognition with raw images.
%
% Usage:
%   run_raw_image_realtime_simulation
%   run_raw_image_realtime_simulation(fullfile(fileparts(pwd), '人脸识别'))
%   run_raw_image_realtime_simulation('D:\Brightmoon\Liner algebra\final_result')
%   run_raw_image_realtime_simulation([], inf, true, 'test')

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(rawDir)
        rawDir = fullfile(fileparts(rootDir), '人脸识别');
    end
    if nargin < 2 || isempty(maxImages)
        maxImages = inf;
    end
    if nargin < 3 || isempty(useAlignedManifest)
        useAlignedManifest = true;
    end
    if nargin < 4 || isempty(splitFilter)
        if useAlignedManifest && ~is_raw_face_dir(rootDir, rawDir)
            splitFilter = 'test';
        else
            splitFilter = '';
        end
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();

    model = load_or_train_model(rootDir, options);
    detector = create_face_detector();
    [alignedLookup, splitLookup] = load_aligned_lookup(rootDir, rawDir, useAlignedManifest);
    records = collect_raw_images(rawDir);
    records = filter_records_by_split(records, splitLookup, splitFilter);
    if isfinite(maxImages)
        records = records(1:min(maxImages, numel(records)));
    end

    resultsDir = fullfile(rootDir, 'results', 'raw_realtime_simulation');
    compareDir = fullfile(resultsDir, 'compare');
    if ~isfolder(compareDir)
        mkdir(compareDir);
    end

    rows = struct('index', {}, 'trueName', {}, 'predName', {}, 'isCorrect', {}, ...
        'elapsedMs', {}, 'faceMode', {}, 'sourcePath', {}, 'facePath', {}, 'comparePath', {});

    fprintf('原图模拟实时识别: %s\n', rawDir);
    fprintf('训练库来源: %s\n', fullfile(rootDir, 'data', 'aligned_faces', 'train'));
    fprintf('图像数: %d\n', numel(records));

    for i = 1:numel(records)
        frame = imread(records(i).imagePath);
        [faceCrop, faceBox, faceMode] = extract_face_for_realtime(frame, detector);
        recognizerInput = faceCrop;
        lookupKey = canonical_path(records(i).imagePath);
        if ~isempty(alignedLookup) && isKey(alignedLookup, lookupKey)
            alignedPath = alignedLookup(lookupKey);
            if isfile(alignedPath)
                recognizerInput = imread(alignedPath);
                faceMode = 'aligned_manifest';
            end
        end

        input = preprocess_for_model(recognizerInput, struct('imageSize', model.imageSize));
        pred = predict_face_identity(model, recognizerInput, options);
        isCorrect = strcmp(pred.name, records(i).label);

        facePath = fullfile(resultsDir, sprintf('%04d_%s_face.jpg', i, records(i).label));
        comparePath = fullfile(compareDir, sprintf('%04d_%s_to_%s.jpg', i, records(i).label, pred.name));
        imwrite(input.image, facePath);
        write_compare_image(frame, faceBox, input.image, records(i).label, pred.name, isCorrect, comparePath);

        rows(end + 1).index = i; %#ok<AGROW>
        rows(end).trueName = records(i).label;
        rows(end).predName = pred.name;
        rows(end).isCorrect = isCorrect;
        rows(end).elapsedMs = pred.elapsedMs;
        rows(end).faceMode = faceMode;
        rows(end).sourcePath = records(i).imagePath;
        rows(end).facePath = facePath;
        rows(end).comparePath = comparePath;

        fprintf('%04d/%04d true=%s pred=%s correct=%d mode=%s time=%.2fms\n', ...
            i, numel(records), records(i).label, pred.name, isCorrect, faceMode, pred.elapsedMs);
    end

    totalCount = numel(rows);
    correctCount = sum([rows.isCorrect]);
    accuracy = correctCount / max(1, totalCount);

    resultCsv = fullfile(resultsDir, 'raw_realtime_results.csv');
    perClassCsv = fullfile(resultsDir, 'raw_realtime_per_class.csv');
    errorCsv = fullfile(resultsDir, 'raw_realtime_errors.csv');
    export_rows(rows, resultCsv);
    export_per_class(rows, perClassCsv);
    export_errors(rows, errorCsv);

    simResult = struct();
    simResult.status = 'ok';
    simResult.message = 'raw image realtime simulation completed';
    simResult.rawDir = rawDir;
    simResult.splitFilter = splitFilter;
    simResult.accuracy = accuracy;
    simResult.correctCount = correctCount;
    simResult.totalCount = totalCount;
    simResult.perImageResults = rows;
    simResult.resultsDir = resultsDir;
    simResult.resultCsv = resultCsv;
    simResult.perClassCsv = perClassCsv;
    simResult.errorCsv = errorCsv;

    fprintf('模拟实时准确率: %.2f%% (%d/%d)\n', accuracy * 100, correctCount, totalCount);
    fprintf('逐图结果: %s\n', resultCsv);
    fprintf('逐人统计: %s\n', perClassCsv);
    fprintf('错分清单: %s\n', errorCsv);
    fprintf('对照图目录: %s\n', compareDir);
end

function [alignedLookup, splitLookup] = load_aligned_lookup(rootDir, rawDir, useAlignedManifest)
    alignedLookup = [];
    splitLookup = [];
    if ~useAlignedManifest
        return;
    end

    manifestPath = resolve_manifest_path(rootDir, rawDir);
    if ~isfile(manifestPath)
        fprintf('未找到对齐清单，退回 Haar/中心裁剪模拟: %s\n', manifestPath);
        return;
    end

    try
        manifest = readtable(manifestPath, 'TextType', 'string', 'Encoding', 'UTF-8');
    catch
        manifest = readtable(manifestPath, 'TextType', 'string');
    end

    if ~all(ismember(["source", "aligned_path"], string(manifest.Properties.VariableNames)))
        fprintf('对齐清单缺少 source/aligned_path 字段，退回 Haar/中心裁剪模拟。\n');
        return;
    end

    alignedLookup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    splitLookup = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:height(manifest)
        sourcePath = char(manifest.source(i));
        alignedPath = char(manifest.aligned_path(i));
        if ~isempty(sourcePath) && ~isempty(alignedPath)
            key = canonical_path(sourcePath);
            alignedLookup(key) = alignedPath;
            if ismember("split", string(manifest.Properties.VariableNames))
                splitLookup(key) = char(manifest.split(i));
            end
        end
    end
    fprintf('已加载对齐清单: %d 条。模拟将优先使用 MediaPipe/手动对齐输入。\n', alignedLookup.Count);
end

function manifestPath = resolve_manifest_path(rootDir, rawDir)
    rawCanonical = lower(canonical_path(rawDir));
    finalResultDir = lower(canonical_path(fullfile(fileparts(rootDir), 'final_result')));
    rawFaceDir = lower(canonical_path(fullfile(fileparts(rootDir), '人脸识别')));

    if strcmp(rawCanonical, rawFaceDir)
        manifestPath = fullfile(rootDir, 'data', 'raw_camera_aligned', 'alignment_split_manifest.csv');
    elseif strcmp(rawCanonical, finalResultDir)
        manifestPath = fullfile(rootDir, 'data', 'aligned_faces', 'alignment_split_manifest.csv');
    else
        manifestPath = fullfile(rootDir, 'data', 'raw_camera_aligned', 'alignment_split_manifest.csv');
    end
end

function tf = is_raw_face_dir(rootDir, rawDir)
    rawCanonical = lower(canonical_path(rawDir));
    rawFaceDir = lower(canonical_path(fullfile(fileparts(rootDir), '人脸识别')));
    tf = strcmp(rawCanonical, rawFaceDir);
end

function records = filter_records_by_split(records, splitLookup, splitFilter)
    if isempty(splitFilter) || isempty(splitLookup)
        return;
    end

    keep = false(1, numel(records));
    for i = 1:numel(records)
        key = canonical_path(records(i).imagePath);
        keep(i) = isKey(splitLookup, key) && strcmp(splitLookup(key), splitFilter);
    end
    records = records(keep);
    fprintf('按 split=%s 过滤后图像数: %d\n', splitFilter, numel(records));
end

function model = load_or_train_model(rootDir, options)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_model.mat');
    modelOut = model_io('load', [], modelPath);
    if strcmp(modelOut.status, 'ok')
        model = modelOut.model;
        return;
    end

    fprintf('未找到已训练模型，先自动训练一次...\n');
    trainDir = fullfile(rootDir, 'data', 'aligned_faces', 'train');
    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('模型训练失败: %s', model.message);
    end
    model_io('save', model, modelPath);
end

function records = collect_raw_images(rawDir)
    suffixes = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff'};
    files = [];
    for i = 1:numel(suffixes)
        files = [files; dir(fullfile(rawDir, '**', suffixes{i}))]; %#ok<AGROW>
    end

    records = struct('imagePath', {}, 'label', {});
    for i = 1:numel(files)
        imagePath = fullfile(files(i).folder, files(i).name);
        [~, stem, ~] = fileparts(files(i).name);
        label = normalize_label(stem);
        records(end + 1).imagePath = imagePath; %#ok<AGROW>
        records(end).label = label;
    end
end

function label = normalize_label(stem)
    label = strtrim(stem);
    label = regexprep(label, '\s*\(\d+\)$', '');
    underscore = strfind(label, '_');
    if ~isempty(underscore)
        label = label(1:underscore(1) - 1);
    end
    label = regexprep(label, '\d+$', '');
    if strcmp(label, '刘驿恺')
        label = '刘毅凯';
    end
end

function pathText = canonical_path(pathText)
    try
        pathText = char(java.io.File(char(pathText)).getCanonicalPath());
    catch
        pathText = char(pathText);
    end
end

function detector = create_face_detector()
    detector = [];
    if exist('vision.CascadeObjectDetector', 'class') == 8
        detector = vision.CascadeObjectDetector('FrontalFaceCART');
        detector.MergeThreshold = 4;
    end
end

function [faceImg, faceBox, faceMode] = extract_face_for_realtime(frame, detector)
    faceBox = [];
    faceMode = 'center_crop';

    if ~isempty(detector)
        boxes = step(detector, frame);
        if ~isempty(boxes)
            areas = boxes(:, 3) .* boxes(:, 4);
            [~, idx] = max(areas);
            faceBox = expand_square_box(boxes(idx, :), size(frame), 0.35);
            faceMode = 'haar_face';
        end
    end

    if isempty(faceBox)
        faceBox = center_square_box(size(frame), 0.72);
    end

    x = faceBox(1);
    y = faceBox(2);
    w = faceBox(3);
    h = faceBox(4);
    faceImg = frame(y:y + h - 1, x:x + w - 1, :);
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

function write_compare_image(frame, faceBox, modelFace, trueName, predName, isCorrect, outPath)
    if ndims(frame) == 2
        frame = repmat(frame, 1, 1, 3);
    end
    frameSmall = im2uint8(resize_rgb(frame, 280, 280));
    faceBig = im2uint8(repmat(resize_gray(modelFace, 280, 230), 1, 1, 3));

    xScale = 280 / size(frame, 2);
    yScale = 280 / size(frame, 1);
    box = [faceBox(1) * xScale, faceBox(2) * yScale, faceBox(3) * xScale, faceBox(4) * yScale];
    frameSmall = insert_rect_fallback(frameSmall, box, isCorrect);

    canvas = uint8(255 * ones(330, 560, 3));
    canvas(1:280, 1:280, :) = frameSmall;
    canvas(1:280, 331:560, :) = faceBig;
    imwrite(canvas, outPath);
end

function out = resize_rgb(img, targetH, targetW)
    out = zeros(targetH, targetW, 3);
    for c = 1:3
        out(:, :, c) = resize_gray(im2double_local(img(:, :, c)), targetH, targetW);
    end
end

function out = resize_gray(img, targetH, targetW)
    [srcH, srcW] = size(img);
    y = linspace(1, srcH, targetH);
    x = linspace(1, srcW, targetW);
    [xGrid, yGrid] = meshgrid(x, y);
    x1 = max(1, floor(xGrid));
    y1 = max(1, floor(yGrid));
    x2 = min(x1 + 1, srcW);
    y2 = min(y1 + 1, srcH);
    dx = xGrid - x1;
    dy = yGrid - y1;
    out = (1 - dx) .* (1 - dy) .* img(sub2ind([srcH, srcW], y1, x1)) + ...
        dx .* (1 - dy) .* img(sub2ind([srcH, srcW], y1, x2)) + ...
        (1 - dx) .* dy .* img(sub2ind([srcH, srcW], y2, x1)) + ...
        dx .* dy .* img(sub2ind([srcH, srcW], y2, x2));
end

function out = im2double_local(img)
    if isa(img, 'uint8')
        out = double(img) / 255;
    elseif isa(img, 'uint16')
        out = double(img) / 65535;
    else
        out = double(img);
        if max(out(:)) > 1
            out = out / 255;
        end
    end
end

function img = insert_rect_fallback(img, box, isCorrect)
    if isCorrect
        color = uint8([0, 220, 0]);
    else
        color = uint8([220, 0, 0]);
    end

    x1 = max(1, round(box(1)));
    y1 = max(1, round(box(2)));
    x2 = min(size(img, 2), round(box(1) + box(3)));
    y2 = min(size(img, 1), round(box(2) + box(4)));

    thickness = 3;
    for t = 0:thickness - 1
        img(max(1, y1 - t):min(size(img, 1), y1 + t), x1:x2, :) = repmat(reshape(color, 1, 1, 3), numel(max(1, y1 - t):min(size(img, 1), y1 + t)), x2 - x1 + 1, 1);
        img(max(1, y2 - t):min(size(img, 1), y2 + t), x1:x2, :) = repmat(reshape(color, 1, 1, 3), numel(max(1, y2 - t):min(size(img, 1), y2 + t)), x2 - x1 + 1, 1);
        img(y1:y2, max(1, x1 - t):min(size(img, 2), x1 + t), :) = repmat(reshape(color, 1, 1, 3), y2 - y1 + 1, numel(max(1, x1 - t):min(size(img, 2), x1 + t)), 1);
        img(y1:y2, max(1, x2 - t):min(size(img, 2), x2 + t), :) = repmat(reshape(color, 1, 1, 3), y2 - y1 + 1, numel(max(1, x2 - t):min(size(img, 2), x2 + t)), 1);
    end
end

function export_rows(rows, outPath)
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'index,trueName,predName,isCorrect,elapsedMs,faceMode,sourcePath,facePath,comparePath\n');
    for i = 1:numel(rows)
        fprintf(fid, '%d,%s,%s,%d,%.6f,%s,%s,%s,%s\n', ...
            rows(i).index, csv_escape(rows(i).trueName), csv_escape(rows(i).predName), ...
            rows(i).isCorrect, rows(i).elapsedMs, csv_escape(rows(i).faceMode), ...
            csv_escape(rows(i).sourcePath), csv_escape(rows(i).facePath), csv_escape(rows(i).comparePath));
    end
    clear cleanup;
end

function export_per_class(rows, outPath)
    labels = unique({rows.trueName}, 'stable');
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'name,correct,total,accuracy\n');
    for i = 1:numel(labels)
        mask = strcmp({rows.trueName}, labels{i});
        total = sum(mask);
        correct = sum([rows(mask).isCorrect]);
        fprintf(fid, '%s,%d,%d,%.6f\n', csv_escape(labels{i}), correct, total, correct / max(1, total));
    end
    clear cleanup;
end

function export_errors(rows, outPath)
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'index,trueName,predName,sourcePath,comparePath\n');
    for i = 1:numel(rows)
        if ~rows(i).isCorrect
            fprintf(fid, '%d,%s,%s,%s,%s\n', rows(i).index, ...
                csv_escape(rows(i).trueName), csv_escape(rows(i).predName), ...
                csv_escape(rows(i).sourcePath), csv_escape(rows(i).comparePath));
        end
    end
    clear cleanup;
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
