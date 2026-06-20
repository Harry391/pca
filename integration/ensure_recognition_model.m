function model = ensure_recognition_model(appState, params)
%ENSURE_RECOGNITION_MODEL Load the committed v11 model, or train as fallback.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    forceTrain = get_param_or(params, 'forceTrain', false);
    if ~forceTrain && isfield(appState, 'model') && isstruct(appState.model) && ...
            isfield(appState.model, 'status') && string(appState.model.status) == "ok"
        model = appState.model;
        return;
    end

    modelPath = get_param_or(params, 'modelPath', get_field_or(appState, 'defaultModelPath', ""));
    if ~forceTrain && strlength(string(modelPath)) > 0 && isfile(char(modelPath))
        loaded = model_io('load', [], char(modelPath));
        if strcmp(loaded.status, 'ok') && isstruct(loaded.model) && ...
                isfield(loaded.model, 'status') && strcmp(loaded.model.status, 'ok')
            model = loaded.model;
            return;
        end
    end

    trainDir = get_param_or(params, 'trainDir', get_field_or(appState, 'defaultTrainDir', fullfile(appState.rootDir, 'data', 'train')));
    if ~isfolder(trainDir)
        trainDir = fullfile(appState.rootDir, 'data');
    end

    pcaDim = get_param_or(params, 'pcaDim', get_field_or(appState, 'defaultPcaDim', 120));
    svmC = get_param_or(params, 'svmC', get_field_or(appState, 'defaultSvmC', 0.03));
    options = recognition_training_options(params);
    model = train_pca_svm_model(trainDir, pcaDim, svmC, options);
end

function options = recognition_training_options(params)
    options = struct();
    options.imageSize = get_param_or(params, 'imageSize', [112, 92]);
    options.topK = get_param_or(params, 'topK', 3);
    options.svmMaxEpochs = get_param_or(params, 'svmMaxEpochs', 1400);
    options.svmLearningRate = get_param_or(params, 'svmLearningRate', 0.035);
    options.svmLearningRateDecay = get_param_or(params, 'svmLearningRateDecay', 0.008);
    if exist('excluded_labels', 'file') == 2
        options.ignoredLabels = excluded_labels();
    else
        options.ignoredLabels = {};
    end
end

function value = get_param_or(params, fieldName, defaultValue)
    if isstruct(params) && isfield(params, fieldName) && ~isempty(params.(fieldName))
        value = params.(fieldName);
    else
        value = defaultValue;
    end
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
