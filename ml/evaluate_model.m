function report = evaluate_model(modelOrTrainDir, testDir, options)
%EVALUATE_MODEL Train if needed, then run batch evaluation.

    if nargin < 3 || isempty(options)
        options = struct();
    end

    if isstruct(modelOrTrainDir)
        model = modelOrTrainDir;
    else
        pcaDim = get_option(options, 'pcaDim', 30);
        svmC = get_option(options, 'svmC', 1.0);
        model = train_pca_svm_model(modelOrTrainDir, pcaDim, svmC, options);
    end

    batchResult = run_batch_test(model, testDir, options);
    report = struct();
    report.status = batchResult.status;
    report.message = batchResult.message;
    report.model = model;
    report.batchResult = batchResult;
    report.accuracy = batchResult.accuracy;
    report.totalElapsedMs = batchResult.totalElapsedMs;
    report.avgElapsedMs = batchResult.avgElapsedMs;
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end
