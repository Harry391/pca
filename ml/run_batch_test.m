function batchResult = run_batch_test(model, testDir, options)
%RUN_BATCH_TEST Evaluate hand-written PCA/SVM on a test directory.

    if nargin < 3 || isempty(options)
        options = struct();
    end

    batchResult = struct('status', 'error', 'message', '', ...
        'accuracy', [], 'totalElapsedMs', [], 'avgElapsedMs', [], ...
        'perImageResults', [], 'confusionSummary', []);

    if ~isfield(model, 'status') || ~strcmp(model.status, 'ok')
        batchResult.message = 'model is not trained';
        return;
    end

    dataset = load_dataset(testDir, options);
    if ~strcmp(dataset.status, 'ok') || isempty(dataset.records)
        batchResult.message = ['failed to load test dataset: ', dataset.message];
        return;
    end

    totalTimer = tic;
    perImageResults = struct('trueName', {}, 'predName', {}, 'isCorrect', {}, 'elapsedMs', {}, 'imagePath', {});

    for i = 1:numel(dataset.records)
        pred = predict_face_identity(model, dataset.records(i).imagePath, options);
        perImageResults(end + 1).trueName = dataset.records(i).label; %#ok<AGROW>
        perImageResults(end).predName = pred.name;
        perImageResults(end).isCorrect = strcmp(dataset.records(i).label, pred.name);
        perImageResults(end).elapsedMs = pred.elapsedMs;
        perImageResults(end).imagePath = dataset.records(i).imagePath;
    end

    correct = [perImageResults.isCorrect];
    totalElapsedMs = toc(totalTimer) * 1000;

    batchResult.status = 'ok';
    batchResult.message = 'batch test completed';
    batchResult.accuracy = sum(correct) / numel(correct);
    batchResult.totalElapsedMs = totalElapsedMs;
    batchResult.avgElapsedMs = mean([perImageResults.elapsedMs]);
    batchResult.perImageResults = perImageResults;
    batchResult.confusionSummary = build_confusion(perImageResults, model.labels);
end

function summary = build_confusion(perImageResults, labels)
    classCount = numel(labels);
    matrix = zeros(classCount, classCount);
    perClassAccuracy = zeros(classCount, 1);

    for i = 1:numel(perImageResults)
        trueIdx = find(strcmp(labels, perImageResults(i).trueName), 1);
        predIdx = find(strcmp(labels, perImageResults(i).predName), 1);
        if ~isempty(trueIdx) && ~isempty(predIdx)
            matrix(trueIdx, predIdx) = matrix(trueIdx, predIdx) + 1;
        end
    end

    for i = 1:classCount
        rowTotal = sum(matrix(i, :));
        if rowTotal > 0
            perClassAccuracy(i) = matrix(i, i) / rowTotal;
        else
            perClassAccuracy(i) = NaN;
        end
    end

    summary = struct();
    summary.labels = labels;
    summary.matrix = matrix;
    summary.perClassAccuracy = perClassAccuracy;
end
