function report = run_tight_masked_pca_svm_experiment(splitDir)
%RUN_TIGHT_MASKED_PCA_SVM_EXPERIMENT Train/test PCA+SVM on tight-masked faces.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(splitDir)
        splitDir = fullfile(rootDir, 'data', 'tight_masked_pca_svm_split_v11');
    end

    trainDir = fullfile(splitDir, 'train');
    testDir = fullfile(splitDir, 'test');
    splitTag = split_tag_from_dir(splitDir);
    resultsDir = fullfile(rootDir, 'results', ['tight_masked_pca_svm_', splitTag]);
    modelPath = fullfile(rootDir, 'models', ['pca_svm_tight_masked_', splitTag, '_model.mat']);

    if ~isfolder(trainDir) || ~isfolder(testDir)
        error('Tight-masked split not found: %s', splitDir);
    end
    if ~isfolder(resultsDir)
        mkdir(resultsDir);
    end

    options = struct();
    options.imageSize = [112, 92];
    options.topK = 3;
    options.svmMaxEpochs = 1400;
    options.svmLearningRate = 0.035;
    options.svmLearningRateDecay = 0.008;
    options.ignoredLabels = excluded_labels();

    fprintf('Training source: %s\n', trainDir);
    fprintf('Testing source: %s\n', testDir);
    fprintf('Ignored labels: %s\n', strjoin(options.ignoredLabels, ', '));

    model = train_pca_svm_model(trainDir, 120, 0.03, options);
    if ~strcmp(model.status, 'ok')
        error('Training failed: %s', model.message);
    end
    model_io('save', model, modelPath);

    batchResult = run_batch_test(model, testDir, options);
    if ~strcmp(batchResult.status, 'ok')
        error('Batch test failed: %s', batchResult.message);
    end

    resultCsv = fullfile(resultsDir, 'tight_masked_test_results.csv');
    perClassCsv = fullfile(resultsDir, 'tight_masked_per_class.csv');
    errorCsv = fullfile(resultsDir, 'tight_masked_errors.csv');
    export_results(batchResult.perImageResults, resultCsv);
    export_per_class(batchResult.perImageResults, model.labels, perClassCsv);
    export_errors(batchResult.perImageResults, errorCsv);

    correctCount = sum([batchResult.perImageResults.isCorrect]);
    totalCount = numel(batchResult.perImageResults);

    report = struct();
    report.status = 'ok';
    report.message = 'tight-masked PCA+SVM experiment completed';
    report.splitDir = splitDir;
    report.trainDir = trainDir;
    report.testDir = testDir;
    report.resultsDir = resultsDir;
    report.modelPath = modelPath;
    report.trainCount = model.trainSummary.trainCount;
    report.testCount = totalCount;
    report.classCount = numel(model.labels);
    report.accuracy = batchResult.accuracy;
    report.correctCount = correctCount;
    report.totalCount = totalCount;
    report.resultCsv = resultCsv;
    report.perClassCsv = perClassCsv;
    report.errorCsv = errorCsv;
    report.model = model;
    report.batchResult = batchResult;

    fprintf('Train/Test count: %d/%d\n', report.trainCount, report.testCount);
    fprintf('Class count: %d\n', report.classCount);
    fprintf('Accuracy: %.2f%% (%d/%d)\n', batchResult.accuracy * 100, correctCount, totalCount);
    fprintf('Model: %s\n', modelPath);
    fprintf('Results: %s\n', resultCsv);
    fprintf('Per-class: %s\n', perClassCsv);
    fprintf('Errors: %s\n', errorCsv);
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

function splitTag = split_tag_from_dir(splitDir)
    [~, splitName] = fileparts(char(splitDir));
    token = regexp(splitName, 'split_(.+)$', 'tokens', 'once');
    if isempty(token)
        splitTag = matlab.lang.makeValidName(splitName);
    else
        splitTag = matlab.lang.makeValidName(token{1});
    end
end
