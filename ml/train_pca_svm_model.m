function model = train_pca_svm_model(trainDir, pcaDim, svmC, options)
%TRAIN_PCA_SVM_MODEL Train hand-written PCA plus hand-written linear SVM.

    if nargin < 2 || isempty(pcaDim)
        pcaDim = 30;
    end
    if nargin < 3 || isempty(svmC)
        svmC = 1.0;
    end
    if nargin < 4 || isempty(options)
        options = struct();
    end

    imageSize = get_option(options, 'imageSize', [112, 92]);
    svmMaxEpochs = get_option(options, 'svmMaxEpochs', 700);
    svmLearningRate = get_option(options, 'svmLearningRate', 0.04);
    svmLearningRateDecay = get_option(options, 'svmLearningRateDecay', 0.01);

    model = empty_model(trainDir, pcaDim, svmC, options);
    model.imageSize = imageSize;

    dataset = load_dataset(trainDir, options);
    if ~strcmp(dataset.status, 'ok') || isempty(dataset.records)
        model.status = 'error';
        model.message = ['failed to load training dataset: ', dataset.message];
        return;
    end

    n = numel(dataset.records);
    d = imageSize(1) * imageSize(2);
    X = zeros(n, d);
    y = zeros(n, 1);

    for i = 1:n
        input = preprocess_for_model(dataset.records(i).imagePath, struct('imageSize', imageSize));
        X(i, :) = input.vector;
        y(i) = dataset.records(i).classIndex;
    end

    meanVector = mean(X, 1);
    centeredX = X - meanVector;
    [eigenVectors, eigenValues] = train_pca_basis(centeredX, pcaDim);
    features = centeredX * eigenVectors;

    featureMean = mean(features, 1);
    featureStd = std(features, 0, 1);
    featureStd(featureStd < 1e-8) = 1;
    featuresStd = (features - featureMean) ./ featureStd;

    svmParams = train_ovr_svm(featuresStd, y, numel(dataset.labels), svmC, ...
        svmMaxEpochs, svmLearningRate, svmLearningRateDecay);
    [classCentroids, trainFeatureNorm] = build_feature_statistics(featuresStd, y, numel(dataset.labels));

    model.status = 'ok';
    model.message = 'hand-written PCA + one-vs-rest linear SVM trained';
    model.labels = dataset.labels;
    model.meanVector = meanVector;
    model.meanFace = reshape(meanVector, imageSize(1), imageSize(2));
    model.eigenfaces = eigenVectors;
    model.eigenvalues = eigenValues;
    model.pcaDim = size(eigenVectors, 2);
    model.featureMean = featureMean;
    model.featureStd = featureStd;
    model.trainFeatures = featuresStd;
    model.trainFeatureNorm = trainFeatureNorm;
    model.trainFeatureLabels = y;
    model.classCentroids = classCentroids;
    model.trainImagePaths = {dataset.records.imagePath};
    model.svmParams = svmParams;
    model.trainSummary = struct( ...
        'trainCount', n, ...
        'classCount', numel(dataset.labels), ...
        'imageSize', imageSize, ...
        'requestedPcaDim', pcaDim, ...
        'actualPcaDim', size(eigenVectors, 2), ...
        'svmStrategy', 'one-vs-rest', ...
        'svmMaxEpochs', svmMaxEpochs, ...
        'excludedLabels', {dataset.ignoredLabels}, ...
        'perClassSummary', dataset.perClassSummary);
    model.trainDir = trainDir;
end

function [classCentroids, featureNorm] = build_feature_statistics(featuresStd, y, classCount)
    featureNorm = sqrt(sum(featuresStd .^ 2, 2));
    featureNorm(featureNorm < 1e-12) = 1;

    classCentroids = zeros(classCount, size(featuresStd, 2));
    for classIndex = 1:classCount
        members = featuresStd(y == classIndex, :);
        if isempty(members)
            continue;
        end
        centroid = mean(members, 1);
        centroidNorm = norm(centroid);
        if centroidNorm > 0
            centroid = centroid / centroidNorm;
        end
        classCentroids(classIndex, :) = centroid;
    end
end

function model = empty_model(trainDir, pcaDim, svmC, options)
    model = struct();
    model.status = 'error';
    model.message = '';
    model.labels = {};
    model.imageSize = [];
    model.meanFace = [];
    model.meanVector = [];
    model.eigenfaces = [];
    model.eigenvalues = [];
    model.pcaDim = pcaDim;
    model.svmC = svmC;
    model.svmParams = [];
    model.trainSummary = [];
    model.trainDir = trainDir;
    model.options = options;
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function [basis, eigenValues] = train_pca_basis(centeredX, requestedDim)
    sampleCount = size(centeredX, 1);
    maxDim = min([requestedDim, sampleCount - 1, size(centeredX, 2)]);
    if maxDim < 1
        error('train_pca_svm_model:NotEnoughSamples', 'at least two training samples are required');
    end

    gram = (centeredX * centeredX') / max(1, sampleCount - 1);
    gram = (gram + gram') / 2;
    [smallVecs, smallVals] = eig(gram);
    vals = real(diag(smallVals));
    [vals, order] = sort(vals, 'descend');
    smallVecs = real(smallVecs(:, order));

    positive = vals > 1e-10;
    vals = vals(positive);
    smallVecs = smallVecs(:, positive);
    keep = min(maxDim, numel(vals));

    vals = vals(1:keep);
    smallVecs = smallVecs(:, 1:keep);
    basis = centeredX' * smallVecs;
    for i = 1:keep
        normValue = norm(basis(:, i));
        if normValue > 0
            basis(:, i) = basis(:, i) / normValue;
        end
    end
    eigenValues = vals(:)';
end

function svmParams = train_ovr_svm(X, y, classCount, C, maxEpochs, lr0, lrDecay)
    featureCount = size(X, 2);
    weights = zeros(classCount, featureCount);
    bias = zeros(classCount, 1);
    objectiveHistory = zeros(classCount, maxEpochs);

    for classIndex = 1:classCount
        binaryY = -ones(size(y));
        binaryY(y == classIndex) = 1;
        [w, b, history] = train_binary_svm(X, binaryY, C, maxEpochs, lr0, lrDecay);
        weights(classIndex, :) = w;
        bias(classIndex) = b;
        objectiveHistory(classIndex, :) = history;
    end

    svmParams = struct();
    svmParams.strategy = 'one-vs-rest';
    svmParams.kernel = 'linear';
    svmParams.weights = weights;
    svmParams.bias = bias;
    svmParams.C = C;
    svmParams.maxEpochs = maxEpochs;
    svmParams.learningRate = lr0;
    svmParams.objectiveHistory = objectiveHistory;
end

function [w, b, history] = train_binary_svm(X, y, C, maxEpochs, lr0, lrDecay)
    n = size(X, 1);
    w = zeros(1, size(X, 2));
    b = 0;
    history = zeros(1, maxEpochs);

    posCount = max(1, sum(y == 1));
    negCount = max(1, sum(y == -1));
    sampleWeights = zeros(n, 1);
    sampleWeights(y == 1) = n / (2 * posCount);
    sampleWeights(y == -1) = n / (2 * negCount);

    for epoch = 1:maxEpochs
        lr = lr0 / (1 + lrDecay * (epoch - 1));
        margins = y .* (X * w' + b);
        active = margins < 1;

        if any(active)
            activeY = y(active);
            activeWeights = sampleWeights(active);
            gradW = w - (C / n) * sum((activeWeights .* activeY) .* X(active, :), 1);
            gradB = -(C / n) * sum(activeWeights .* activeY);
        else
            gradW = w;
            gradB = 0;
        end

        w = w - lr * gradW;
        b = b - lr * gradB;

        hinge = max(0, 1 - margins);
        history(epoch) = 0.5 * sum(w .^ 2) + (C / n) * sum(sampleWeights .* hinge);
    end
end
