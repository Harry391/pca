function report = run_auto_points_pca_svm_experiment(sourceDir, splitDir)
%RUN_AUTO_POINTS_PCA_SVM_EXPERIMENT Evaluate MATLAB-aligned auto-point faces.
%
% Source images are expected to be MATLAB outputs generated from the
% auto-click coordinate CSV. This script creates a train/test split with
% exactly two test images per person when possible, then trains and tests the
% hand-written PCA + SVM pipeline.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(sourceDir)
        sourceDir = fullfile(rootDir, 'data', 'matlab_aligned_from_auto_points');
    end
    if nargin < 2 || isempty(splitDir)
        splitDir = fullfile(rootDir, 'data', 'matlab_auto_points_pca_svm_split');
    end

    trainDir = fullfile(splitDir, 'train');
    testDir = fullfile(splitDir, 'test');
    resultsDir = fullfile(rootDir, 'results', 'matlab_auto_points_pca_svm');
    modelPath = fullfile(rootDir, 'models', 'pca_svm_auto_points_model.mat');

    splitSummary = make_two_test_split(sourceDir, splitDir, 2, 20260616);

    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = {};

    fprintf('Training source: %s\n', trainDir);
    fprintf('Testing source: %s\n', testDir);
    fprintf('Train/Test count: %d/%d\n', splitSummary.trainCount, splitSummary.testCount);
    fprintf('Class count: %d\n', numel(splitSummary.labels));

    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('Training failed: %s', model.message);
    end
    model_io('save', model, modelPath);

    batchResult = run_batch_test(model, testDir, options);
    if ~strcmp(batchResult.status, 'ok')
        error('Batch test failed: %s', batchResult.message);
    end

    resultCsv = fullfile(resultsDir, 'auto_points_test_results.csv');
    perClassCsv = fullfile(resultsDir, 'auto_points_per_class.csv');
    errorCsv = fullfile(resultsDir, 'auto_points_errors.csv');
    splitCsv = fullfile(resultsDir, 'auto_points_split.csv');
    export_split(splitSummary.rows, splitCsv);
    export_results(batchResult.perImageResults, resultCsv);
    export_per_class(batchResult.perImageResults, splitSummary.labels, perClassCsv);
    export_errors(batchResult.perImageResults, errorCsv);

    correctCount = sum([batchResult.perImageResults.isCorrect]);
    totalCount = numel(batchResult.perImageResults);

    report = struct();
    report.status = 'ok';
    report.message = 'auto-point MATLAB-aligned PCA+SVM experiment completed';
    report.sourceDir = sourceDir;
    report.splitDir = splitDir;
    report.trainDir = trainDir;
    report.testDir = testDir;
    report.resultsDir = resultsDir;
    report.modelPath = modelPath;
    report.trainCount = splitSummary.trainCount;
    report.testCount = splitSummary.testCount;
    report.classCount = numel(splitSummary.labels);
    report.accuracy = batchResult.accuracy;
    report.correctCount = correctCount;
    report.totalCount = totalCount;
    report.resultCsv = resultCsv;
    report.perClassCsv = perClassCsv;
    report.errorCsv = errorCsv;
    report.splitCsv = splitCsv;
    report.model = model;
    report.batchResult = batchResult;

    fprintf('Accuracy: %.2f%% (%d/%d)\n', batchResult.accuracy * 100, correctCount, totalCount);
    fprintf('Results: %s\n', resultCsv);
    fprintf('Per-class: %s\n', perClassCsv);
    fprintf('Errors: %s\n', errorCsv);
    fprintf('Split: %s\n', splitCsv);
end

function splitSummary = make_two_test_split(sourceDir, splitDir, testPerClass, seed)
    if ~isfolder(sourceDir)
        error('Source directory not found: %s', sourceDir);
    end

    if isfolder(splitDir)
        rmdir(splitDir, 's');
    end
    trainDir = fullfile(splitDir, 'train');
    testDir = fullfile(splitDir, 'test');
    mkdir(trainDir);
    mkdir(testDir);

    labels = list_labels(sourceDir);
    rng(seed);

    rows = struct('sourcePath', {}, 'splitPath', {}, 'label', {}, 'split', {});
    trainCount = 0;
    testCount = 0;

    for labelIndex = 1:numel(labels)
        label = labels{labelIndex};
        files = list_images(fullfile(sourceDir, label));
        if isempty(files)
            continue;
        end

        order = randperm(numel(files));
        testCountForLabel = min(testPerClass, max(1, numel(files) - 1));
        testIndices = sort(order(1:testCountForLabel));

        for i = 1:numel(files)
            if ismember(i, testIndices)
                splitName = 'test';
                targetRoot = testDir;
                testCount = testCount + 1;
            else
                splitName = 'train';
                targetRoot = trainDir;
                trainCount = trainCount + 1;
            end

            targetDir = fullfile(targetRoot, label);
            if ~isfolder(targetDir)
                mkdir(targetDir);
            end
            targetPath = fullfile(targetDir, files(i).name);
            copyfile(fullfile(files(i).folder, files(i).name), targetPath);

            rows(end + 1).sourcePath = fullfile(files(i).folder, files(i).name); %#ok<AGROW>
            rows(end).splitPath = targetPath;
            rows(end).label = label;
            rows(end).split = splitName;
        end
    end

    splitSummary = struct();
    splitSummary.labels = labels;
    splitSummary.rows = rows;
    splitSummary.trainCount = trainCount;
    splitSummary.testCount = testCount;
end

function labels = list_labels(sourceDir)
    dirs = dir(sourceDir);
    labels = {};
    for i = 1:numel(dirs)
        if dirs(i).isdir && ~startsWith(dirs(i).name, '.')
            labelDir = fullfile(dirs(i).folder, dirs(i).name);
            if ~isempty(list_images(labelDir))
                labels{end + 1} = dirs(i).name; %#ok<AGROW>
            end
        end
    end
    labels = sort(labels);
end

function files = list_images(folder)
    suffixes = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff', '*.webp'};
    files = [];
    for i = 1:numel(suffixes)
        files = [files; dir(fullfile(folder, suffixes{i}))]; %#ok<AGROW>
    end
    [~, order] = sort({files.name});
    files = files(order);
end

function export_split(rows, outPath)
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'label,split,sourcePath,splitPath\n');
    for i = 1:numel(rows)
        fprintf(fid, '%s,%s,%s,%s\n', csv_escape(rows(i).label), csv_escape(rows(i).split), ...
            csv_escape(rows(i).sourcePath), csv_escape(rows(i).splitPath));
    end
    clear cleanup;
end

function export_results(rows, outPath)
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'trueName,predName,isCorrect,elapsedMs,imagePath\n');
    for i = 1:numel(rows)
        fprintf(fid, '%s,%s,%d,%.6f,%s\n', csv_escape(rows(i).trueName), csv_escape(rows(i).predName), ...
            rows(i).isCorrect, rows(i).elapsedMs, csv_escape(rows(i).imagePath));
    end
    clear cleanup;
end

function export_per_class(rows, labels, outPath)
    fid = fopen(outPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'label,correct,total,accuracy\n');
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
    fprintf(fid, 'trueName,predName,elapsedMs,imagePath\n');
    for i = 1:numel(rows)
        if ~rows(i).isCorrect
            fprintf(fid, '%s,%s,%.6f,%s\n', csv_escape(rows(i).trueName), csv_escape(rows(i).predName), ...
                rows(i).elapsedMs, csv_escape(rows(i).imagePath));
        end
    end
    clear cleanup;
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
