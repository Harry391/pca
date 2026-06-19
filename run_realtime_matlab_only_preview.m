function result = run_realtime_matlab_only_preview(imagePath, showFigure)
%RUN_REALTIME_MATLAB_ONLY_PREVIEW Offline preview for MATLAB-only realtime pipeline.
%
% Usage:
%   result = run_realtime_matlab_only_preview();
%   result = run_realtime_matlab_only_preview('D:\path\to\image.jpg');
%   result = run_realtime_matlab_only_preview('D:\path\to\image.jpg', false);

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(imagePath)
        [f, p] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'});
        if isequal(f, 0)
            result = [];
            return;
        end
        imagePath = fullfile(p, f);
    end
    if nargin < 2 || isempty(showFigure)
        showFigure = true;
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.detectorMode = 'robust';
    options.useEqualizedSearch = true;
    options.minFaceRatio = 0.68;
    options.facePadding = 0.18;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = {};

    model = load_or_train_auto_points_model(rootDir, options);
    frame = imread(imagePath);
    result = realtime_matlab_align_and_predict(model, frame, options);
    result.imagePath = imagePath;

    if showFigure
        figure('Name', 'MATLAB-only Realtime Preview', 'NumberTitle', 'off', 'Color', 'w');
        subplot(1, 2, 1);
        imshow(frame, []);
        hold on;
        if ~isempty(result.faceBox)
            rectangle('Position', result.faceBox, 'EdgeColor', 'g', 'LineWidth', 2);
        end
        title('Input Frame', 'Interpreter', 'none');
        hold off;

        subplot(1, 2, 2);
        imshow(result.alignedFace, []);
        title(build_title_lines(result), 'Interpreter', 'none');
    end

    fprintf('Image: %s\n', imagePath);
    fprintf('Align status: %s\n', result.alignStatus);
    fprintf('Top-3:\n');
    for i = 1:min(3, numel(result.topKNames))
        fprintf('  %d. %s (%.4f)\n', i, result.topKNames{i}, result.topKScores(i));
    end
    fprintf('Align+predict time: %.2f ms\n', result.alignAndPredictMs);
end

function model = load_or_train_auto_points_model(rootDir, options)
    modelPath = fullfile(rootDir, 'models', 'pca_svm_auto_points_model.mat');
    loaded = model_io('load', [], modelPath);
    if strcmp(loaded.status, 'ok')
        model = loaded.model;
        return;
    end

    trainDir = fullfile(rootDir, 'data', 'matlab_auto_points_pca_svm_split', 'train');
    if ~isfolder(trainDir)
        report = run_auto_points_pca_svm_experiment();
        model = report.model;
        return;
    end

    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('Model training failed: %s', model.message);
    end
    model_io('save', model, modelPath);
end

function lines = build_title_lines(result)
    lines = { ...
        'Recognizer Input 112x92', ...
        sprintf('Align: %s', result.alignStatus), ...
        sprintf('Time: %.2f ms', result.alignAndPredictMs)};
    for i = 1:min(3, numel(result.topKNames))
        lines{end + 1} = sprintf('%d. %s (%.4f)', i, result.topKNames{i}, result.topKScores(i)); %#ok<AGROW>
    end
end
