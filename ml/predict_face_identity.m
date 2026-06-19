function result = predict_face_identity(model, imageData, options)
%PREDICT_FACE_IDENTITY Predict one image with hand-written PCA/SVM.

    if nargin < 3 || isempty(options)
        options = struct();
    end

    result = struct('status', 'error', 'message', '', ...
        'name', '', 'topKNames', {{}}, 'topKScores', [], 'faceBox', [], ...
        'alignedFace', [], 'elapsedMs', []);

    timerHandle = tic;

    if ~isfield(model, 'status') || ~strcmp(model.status, 'ok')
        result.message = 'model is not trained';
        result.elapsedMs = toc(timerHandle) * 1000;
        return;
    end

    topK = get_option(options, 'topK', 3);
    fusionMode = get_option(options, 'fusionMode', 'svm');
    input = preprocess_for_model(imageData, struct('imageSize', model.imageSize));
    feature = project_feature(model, input.vector);
    svmScores = feature * model.svmParams.weights' + model.svmParams.bias';
    scores = combine_scores(model, feature, svmScores, fusionMode, options);
    [sortedScores, order] = sort(scores, 'descend');

    keep = min(topK, numel(order));
    topIndices = order(1:keep);

    result.status = 'ok';
    result.message = 'prediction completed';
    result.name = model.labels{topIndices(1)};
    result.topKNames = model.labels(topIndices);
    result.topKScores = sortedScores(1:keep);
    result.faceBox = [];
    result.alignedFace = input.image;
    result.elapsedMs = toc(timerHandle) * 1000;
end

function scores = combine_scores(model, feature, svmScores, fusionMode, options)
    if strcmpi(fusionMode, 'svm')
        scores = svmScores;
        return;
    end

    classCount = numel(model.labels);
    switch lower(char(fusionMode))
        case {'svm_centroid_nn', 'fusion', 'enhanced'}
            weights = get_option(options, 'fusionWeights', [0.45, 0.25, 0.30]);
            if numel(weights) ~= 3 || sum(abs(weights)) <= eps
                weights = [0.45, 0.25, 0.30];
            end
            weights = weights(:)' / sum(weights);

            centroidScores = compute_centroid_scores(model, feature, classCount);
            nnScores = compute_nn_scores(model, feature, classCount, get_option(options, 'nnTopK', 3));
            scores = ...
                weights(1) * normalize_scores(svmScores) + ...
                weights(2) * normalize_scores(centroidScores) + ...
                weights(3) * normalize_scores(nnScores);

        otherwise
            scores = svmScores;
    end
end

function scores = compute_centroid_scores(model, feature, classCount)
    scores = zeros(1, classCount);
    if ~isfield(model, 'classCentroids') || isempty(model.classCentroids)
        return;
    end

    queryNorm = max(norm(feature), 1e-12);
    scores = (model.classCentroids * feature')' ./ queryNorm;
end

function scores = compute_nn_scores(model, feature, classCount, nnTopK)
    scores = zeros(1, classCount);
    if ~isfield(model, 'trainFeatures') || isempty(model.trainFeatures) || ...
            ~isfield(model, 'trainFeatureLabels') || isempty(model.trainFeatureLabels)
        return;
    end

    nnTopK = max(1, round(nnTopK));
    queryNorm = max(norm(feature), 1e-12);
    trainNorm = model.trainFeatureNorm;
    trainNorm(trainNorm < 1e-12) = 1;
    cosineScores = (model.trainFeatures * feature') ./ (trainNorm * queryNorm);

    for classIndex = 1:classCount
        classScores = cosineScores(model.trainFeatureLabels == classIndex);
        if isempty(classScores)
            continue;
        end
        classScores = sort(classScores, 'descend');
        keep = min(nnTopK, numel(classScores));
        scores(classIndex) = mean(classScores(1:keep));
    end
end

function out = normalize_scores(scores)
    scores = double(scores(:)');
    minValue = min(scores);
    maxValue = max(scores);
    if maxValue <= minValue
        out = zeros(size(scores));
    else
        out = (scores - minValue) / (maxValue - minValue);
    end
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function feature = project_feature(model, vector)
    centered = vector - model.meanVector;
    feature = centered * model.eigenfaces;
    feature = (feature - model.featureMean) ./ model.featureStd;
end
