function splitInfo = split_dataset_2_8(dataset, options)
%SPLIT_DATASET_2_8 Split each class into 8 training and 2 test samples.
% The historical file name is kept for compatibility; the implemented ratio
% is train:test = 8:2.

    if nargin < 2 || isempty(options)
        options = struct();
    end

    trainPerClass = get_option(options, 'trainPerClass', 8);
    testPerClass = get_option(options, 'testPerClass', 2);
    seed = get_option(options, 'seed', 20260615);
    copyFiles = get_option(options, 'copyFiles', false);
    trainDir = get_option(options, 'trainDir', '');
    testDir = get_option(options, 'testDir', '');

    splitInfo = struct();
    splitInfo.status = 'error';
    splitInfo.message = '';
    splitInfo.trainRecords = struct([]);
    splitInfo.testRecords = struct([]);
    splitInfo.splitRatio = [trainPerClass, testPerClass];
    splitInfo.trainCount = 0;
    splitInfo.testCount = 0;
    splitInfo.perClassSummary = struct('label', {}, 'totalCount', {}, 'trainCount', {}, 'testCount', {}, 'status', {});

    if ischar(dataset) || isstring(dataset)
        dataset = load_dataset(char(dataset));
    end

    if ~isfield(dataset, 'status') || ~strcmp(dataset.status, 'ok')
        splitInfo.message = 'dataset is not loaded';
        return;
    end

    if isempty(dataset.records)
        splitInfo.status = 'ok';
        splitInfo.message = 'empty dataset';
        return;
    end

    oldRng = rng;
    rng(seed, 'twister');
    cleanup = onCleanup(@() rng(oldRng));

    labels = dataset.labels;
    trainRecords = struct('imagePath', {}, 'fileName', {}, 'label', {}, 'classIndex', {}, 'split', {}, 'splitPath', {});
    testRecords = trainRecords;

    for i = 1:numel(labels)
        label = labels{i};
        labelRecords = dataset.records(strcmp({dataset.records.label}, label));
        [~, order] = sort({labelRecords.fileName});
        labelRecords = labelRecords(order);

        expected = trainPerClass + testPerClass;
        if numel(labelRecords) == expected
            trainCount = trainPerClass;
        else
            trainCount = max(1, round(numel(labelRecords) * trainPerClass / expected));
            trainCount = min(trainCount, max(0, numel(labelRecords) - 1));
        end

        shuffledOrder = randperm(numel(labelRecords));
        trainIdx = sort(shuffledOrder(1:trainCount));
        testIdx = setdiff(1:numel(labelRecords), trainIdx);

        for j = trainIdx
            record = add_split_fields(labelRecords(j), 'train', trainDir);
            trainRecords(end + 1) = record; %#ok<AGROW>
        end

        for j = testIdx
            record = add_split_fields(labelRecords(j), 'test', testDir);
            testRecords(end + 1) = record; %#ok<AGROW>
        end

        classStatus = 'ok';
        if numel(labelRecords) ~= expected
            classStatus = 'count_not_10_adjusted';
        end

        splitInfo.perClassSummary(end + 1).label = label; %#ok<AGROW>
        splitInfo.perClassSummary(end).totalCount = numel(labelRecords);
        splitInfo.perClassSummary(end).trainCount = trainCount;
        splitInfo.perClassSummary(end).testCount = numel(labelRecords) - trainCount;
        splitInfo.perClassSummary(end).status = classStatus;
    end

    if copyFiles
        if isempty(trainDir) || isempty(testDir)
            splitInfo.message = 'copyFiles requires options.trainDir and options.testDir';
            return;
        end
        copy_records(trainRecords);
        copy_records(testRecords);
    end

    splitInfo.status = 'ok';
    splitInfo.message = 'train:test split completed as 8:2';
    splitInfo.trainRecords = trainRecords;
    splitInfo.testRecords = testRecords;
    splitInfo.trainCount = numel(trainRecords);
    splitInfo.testCount = numel(testRecords);

    clear cleanup;
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end

function record = add_split_fields(record, splitName, splitRoot)
    record.split = splitName;
    if isempty(splitRoot)
        record.splitPath = '';
    else
        record.splitPath = fullfile(splitRoot, record.label, record.fileName);
    end
end

function copy_records(records)
    for i = 1:numel(records)
        targetPath = records(i).splitPath;
        targetDir = fileparts(targetPath);
        if ~isfolder(targetDir)
            mkdir(targetDir);
        end
        copyfile(records(i).imagePath, targetPath);
    end
end
