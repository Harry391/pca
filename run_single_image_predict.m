function result = run_single_image_predict(imagePath)
%RUN_SINGLE_IMAGE_PREDICT Pick one image and output the predicted identity.
%
% Usage:
%   run_single_image_predict
%   run_single_image_predict('D:\path\to\image.jpg')

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));
    add_runtime_services(rootDir);
    runtimeCleanup = onCleanup(@() cleanup_runtime_services(rootDir)); %#ok<NASGU>

    if nargin < 1 || isempty(imagePath)
        [fileName, fileDir] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'}, ...
            'Select One Face Image');
        if isequal(fileName, 0)
            result = struct('status', 'cancelled', 'message', 'No image selected');
            return;
        end
        imagePath = fullfile(fileDir, fileName);
    end

    model = load_or_train_model(rootDir);
    [alignedImage, alignStatus, alignedPath] = align_input_image(rootDir, imagePath);
    pred = predict_face_identity(model, alignedImage, struct('topK', 3));
    diagnostics = compute_similarity_diagnostics(model, alignedImage, 3);

    result = struct();
    result.status = pred.status;
    result.message = pred.message;
    result.imagePath = imagePath;
    result.alignedPath = alignedPath;
    result.alignStatus = alignStatus;
    result.name = pred.name;
    result.topKNames = pred.topKNames;
    result.topKScores = pred.topKScores;
    result.cosineNNNames = diagnostics.cosineNNNames;
    result.cosineNNScores = diagnostics.cosineNNScores;
    result.centroidNames = diagnostics.centroidNames;
    result.centroidScores = diagnostics.centroidScores;
    result.elapsedMs = pred.elapsedMs;

    fprintf('Image: %s\n', imagePath);
    fprintf('Align status: %s\n', alignStatus);
    fprintf('Predicted name: %s\n', pred.name);
    if ~isempty(pred.topKNames)
        fprintf('SVM Top-3:\n');
        for i = 1:numel(pred.topKNames)
            fprintf('  %d. %s (%.4f)\n', i, pred.topKNames{i}, pred.topKScores(i));
        end
    end
    if ~isempty(diagnostics.cosineNNNames)
        fprintf('Cosine NN Top-3:\n');
        for i = 1:numel(diagnostics.cosineNNNames)
            fprintf('  %d. %s (%.4f)\n', i, diagnostics.cosineNNNames{i}, diagnostics.cosineNNScores(i));
        end
    end
    if ~isempty(diagnostics.centroidNames)
        fprintf('Centroid Cosine Top-3:\n');
        for i = 1:numel(diagnostics.centroidNames)
            fprintf('  %d. %s (%.4f)\n', i, diagnostics.centroidNames{i}, diagnostics.centroidScores(i));
        end
    end
    fprintf('Prediction time: %.3f ms\n', pred.elapsedMs);

    show_single_prediction(imagePath, alignedImage, pred, diagnostics, alignStatus);
end

function model = load_or_train_model(rootDir)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_tight_masked_v11_model.mat');
    loaded = model_io('load', [], modelPath);
    if strcmp(loaded.status, 'ok')
        model = loaded.model;
        return;
    end

    fprintf('No trained model found. Training one first...\n');
    options = struct();
    options.imageSize = [112, 92];
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();
    trainDir = fullfile(rootDir, 'data', 'tight_masked_pca_svm_split_v11', 'train');
    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('Model training failed: %s', model.message);
    end
    model_io('save', model, modelPath);
end

function [alignedImage, alignStatus, alignedPath] = align_input_image(rootDir, imagePath)
    tempDir = fullfile(rootDir, 'results', 'single_predict_temp');
    if ~isfolder(tempDir)
        mkdir(tempDir);
    end

    alignedPath = fullfile(tempDir, 'aligned_input.jpg');
    [alignedImage, alignStatus, alignmentLog] = runtime_align_single_face( ...
        rootDir, imagePath, alignedPath, [112, 92]);
    if isempty(alignedImage)
        warning('SingleImagePredict:AlignFailed', ...
            'Automatic alignment failed, fallback to direct preprocessing.\n%s', alignmentLog);
        alignStatus = 'fallback_preprocess_only';
        alignedImage = preprocess_for_model(imagePath, struct('imageSize', [112, 92])).image;
        alignedPath = '';
        return;
    end
end

function diagnostics = compute_similarity_diagnostics(model, alignedImage, topK)
    input = preprocess_for_model(alignedImage, struct('imageSize', model.imageSize));
    feature = (input.vector - model.meanVector) * model.eigenfaces;
    feature = (feature - model.featureMean) ./ model.featureStd;

    diagnostics = struct();
    diagnostics.cosineNNNames = {};
    diagnostics.cosineNNScores = [];
    diagnostics.centroidNames = {};
    diagnostics.centroidScores = [];

    if isfield(model, 'trainFeatures') && ~isempty(model.trainFeatures)
        queryNorm = max(norm(feature), 1e-12);
        cosineScores = (model.trainFeatures * feature') ./ (model.trainFeatureNorm * queryNorm);
        [sortedScores, order] = sort(cosineScores, 'descend');
        keep = min(topK, numel(order));
        diagnostics.cosineNNNames = cell(1, keep);
        diagnostics.cosineNNScores = sortedScores(1:keep);
        for i = 1:keep
            diagnostics.cosineNNNames{i} = model.labels{model.trainFeatureLabels(order(i))};
        end
    end

    if isfield(model, 'classCentroids') && ~isempty(model.classCentroids)
        queryNorm = max(norm(feature), 1e-12);
        centroidScores = (model.classCentroids * feature') ./ queryNorm;
        [sortedScores, order] = sort(centroidScores, 'descend');
        keep = min(topK, numel(order));
        diagnostics.centroidNames = model.labels(order(1:keep));
        diagnostics.centroidScores = sortedScores(1:keep);
    end
end

function show_single_prediction(imagePath, alignedImage, pred, diagnostics, alignStatus)
    original = imread(imagePath);
    fig = figure('Name', 'Single Image Prediction', 'NumberTitle', 'off', 'Color', 'w');
    subplot(1, 2, 1);
    imshow(original, []);
    title('Original Image', 'Interpreter', 'none');

    subplot(1, 2, 2);
    imshow(alignedImage, []);
    title(sprintf('Input | SVM:%s | NN:%s | %s', ...
        pred.name, first_or_dash(diagnostics.cosineNNNames), alignStatus), 'Interpreter', 'none');

    if ~ishandle(fig)
        return;
    end
end

function text = first_or_dash(values)
    if isempty(values)
        text = '-';
    else
        text = values{1};
    end
end
