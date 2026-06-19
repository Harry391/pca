function report = run_pca_svm_experiment()
%RUN_PCA_SVM_EXPERIMENT Train and test the hand-written PCA/SVM pipeline.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    trainDir = fullfile(rootDir, 'data', 'aligned_faces', 'train');
    testDir = fullfile(rootDir, 'data', 'aligned_faces', 'test');
    modelPath = fullfile(rootDir, 'models', 'pca_svm_model.mat');
    resultsDir = fullfile(rootDir, 'results');

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();

    pcaDim = 120;
    svmC = 0.03;

    fprintf('Training hand-written PCA + SVM...\n');
    model = train_pca_svm_model(trainDir, pcaDim, svmC, options);
    if ~strcmp(model.status, 'ok')
        error('Training failed: %s', model.message);
    end

    model_io('save', model, modelPath);

    fprintf('Running batch test...\n');
    batchResult = run_batch_test(model, testDir, options);
    if ~strcmp(batchResult.status, 'ok')
        error('Batch test failed: %s', batchResult.message);
    end
    export_experiment_results(batchResult, resultsDir);

    report = struct();
    report.status = 'ok';
    report.model = model;
    report.batchResult = batchResult;
    report.accuracy = batchResult.accuracy;
    report.modelPath = modelPath;

    fprintf('Accuracy: %.2f%% (%d/%d)\n', ...
        batchResult.accuracy * 100, ...
        round(batchResult.accuracy * numel(batchResult.perImageResults)), ...
        numel(batchResult.perImageResults));
    fprintf('Average prediction time: %.3f ms\n', batchResult.avgElapsedMs);
    fprintf('Per-image results: %s\n', fullfile(resultsDir, 'batch_test_results.csv'));
    fprintf('Confusion matrix: %s\n', fullfile(resultsDir, 'confusion_matrix.csv'));
end

function export_experiment_results(batchResult, resultsDir)
    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    resultPath = fullfile(resultsDir, 'batch_test_results.csv');
    fid = fopen(resultPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'trueName,predName,isCorrect,elapsedMs,imagePath\n');
    for i = 1:numel(batchResult.perImageResults)
        row = batchResult.perImageResults(i);
        fprintf(fid, '%s,%s,%d,%.6f,%s\n', ...
            csv_escape(row.trueName), ...
            csv_escape(row.predName), ...
            row.isCorrect, ...
            row.elapsedMs, ...
            csv_escape(row.imagePath));
    end
    clear cleanup;

    confusionPath = fullfile(resultsDir, 'confusion_matrix.csv');
    fid = fopen(confusionPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    labels = batchResult.confusionSummary.labels;
    fprintf(fid, 'true\\pred');
    for i = 1:numel(labels)
        fprintf(fid, ',%s', csv_escape(labels{i}));
    end
    fprintf(fid, '\n');
    for i = 1:numel(labels)
        fprintf(fid, '%s', csv_escape(labels{i}));
        for j = 1:numel(labels)
            fprintf(fid, ',%d', batchResult.confusionSummary.matrix(i, j));
        end
        fprintf(fid, '\n');
    end
    clear cleanup;
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
