function manifest = export_dataset_manifest(dataDir, trainDir, testDir, classSizeInfo)
%EXPORT_DATASET_MANIFEST Build dataset integrity and 8:2 split summary.

    if nargin < 4
        classSizeInfo = struct();
    end

    rawDataset = load_dataset(dataDir);
    trainDataset = load_dataset(trainDir);
    testDataset = load_dataset(testDir);

    expectedPerClass = get_field(classSizeInfo, 'expectedPerClass', 10);
    expectedClassCount = get_field(classSizeInfo, 'expectedClassCount', numel(rawDataset.labels));
    expectedRawCount = expectedPerClass * expectedClassCount;

    labels = unique([rawDataset.labels, trainDataset.labels, testDataset.labels], 'stable');
    perClassSummary = struct('label', {}, 'rawCount', {}, 'trainCount', {}, 'testCount', {}, 'status', {});

    for i = 1:numel(labels)
        label = labels{i};
        rawCount = count_label(rawDataset, label);
        trainCount = count_label(trainDataset, label);
        testCount = count_label(testDataset, label);

        status = 'ok';
        if rawCount ~= expectedPerClass
            status = 'raw_count_mismatch';
        elseif trainCount ~= 8 || testCount ~= 2
            status = 'split_count_mismatch';
        end

        perClassSummary(end + 1).label = label; %#ok<AGROW>
        perClassSummary(end).rawCount = rawCount;
        perClassSummary(end).trainCount = trainCount;
        perClassSummary(end).testCount = testCount;
        perClassSummary(end).status = status;
    end

    manifest = struct();
    manifest.totalRawCount = rawDataset.totalCount;
    manifest.expectedRawCount = expectedRawCount;
    manifest.trainCount = trainDataset.totalCount;
    manifest.testCount = testDataset.totalCount;
    manifest.splitRatio = [8, 2];
    manifest.perClassSummary = perClassSummary;
    manifest.status = 'ok';
    manifest.message = 'dataset manifest exported';
    manifest.dataDir = dataDir;
    manifest.trainDir = trainDir;
    manifest.testDir = testDir;
    manifest.classSizeInfo = classSizeInfo;

    if rawDataset.totalCount ~= expectedRawCount
        manifest.status = 'warning';
        manifest.message = 'raw dataset count does not match expected count';
    elseif any(~strcmp({perClassSummary.status}, 'ok'))
        manifest.status = 'warning';
        manifest.message = 'per-class count or split ratio mismatch';
    end
end

function value = get_field(s, name, defaultValue)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    else
        value = defaultValue;
    end
end

function n = count_label(dataset, label)
    if ~isfield(dataset, 'records') || isempty(dataset.records)
        n = 0;
        return;
    end
    n = sum(strcmp({dataset.records.label}, label));
end
