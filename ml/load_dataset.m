function dataset = load_dataset(dataDir, options)
%LOAD_DATASET Read face images and infer labels from folders or filenames.

    if nargin < 1 || isempty(dataDir)
        dataDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'data');
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end

    ignoredLabels = get_option(options, 'ignoredLabels', {});

    dataset = struct();
    dataset.status = 'error';
    dataset.message = '';
    dataset.dataDir = char(dataDir);
    dataset.records = struct('imagePath', {}, 'fileName', {}, 'label', {}, 'classIndex', {});
    dataset.labels = {};
    dataset.totalCount = 0;
    dataset.perClassSummary = struct('label', {}, 'count', {});

    if ~isfolder(dataDir)
        dataset.message = ['dataDir does not exist: ', char(dataDir)];
        return;
    end

    suffixes = {'.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.webp'};
    files = [];
    for i = 1:numel(suffixes)
        files = [files; dir(fullfile(dataDir, '**', ['*', suffixes{i}]))]; %#ok<AGROW>
    end

    if isempty(files)
        dataset.status = 'ok';
        dataset.message = 'no image files found';
        return;
    end

    rootDir = char(java.io.File(char(dataDir)).getCanonicalPath());
    rawRecords = struct('imagePath', {}, 'fileName', {}, 'label', {});

    for i = 1:numel(files)
        imagePath = fullfile(files(i).folder, files(i).name);
        label = infer_label(imagePath, rootDir);
        rawRecords(end + 1).imagePath = imagePath; %#ok<AGROW>
        rawRecords(end).fileName = files(i).name;
        rawRecords(end).label = label;
    end

    filteredLabelList = {};
    for i = 1:numel(rawRecords)
        if ~ismember(rawRecords(i).label, ignoredLabels)
            filteredLabelList{end + 1} = rawRecords(i).label; %#ok<AGROW>
        end
    end
    labels = unique(filteredLabelList, 'stable');
    records = struct('imagePath', {}, 'fileName', {}, 'label', {}, 'classIndex', {});
    for i = 1:numel(rawRecords)
        if ismember(rawRecords(i).label, ignoredLabels)
            continue;
        end
        classIndex = find(strcmp(labels, rawRecords(i).label), 1);
        records(end + 1).imagePath = rawRecords(i).imagePath; %#ok<AGROW>
        records(end).fileName = rawRecords(i).fileName;
        records(end).label = rawRecords(i).label;
        records(end).classIndex = classIndex;
    end

    perClassSummary = struct('label', {}, 'count', {});
    for i = 1:numel(labels)
        perClassSummary(end + 1).label = labels{i}; %#ok<AGROW>
        perClassSummary(end).count = sum(strcmp({records.label}, labels{i}));
    end

    dataset.status = 'ok';
    dataset.message = 'dataset loaded';
    dataset.records = records;
    dataset.labels = labels;
    dataset.totalCount = numel(records);
    dataset.perClassSummary = perClassSummary;
    dataset.ignoredLabels = ignoredLabels;
end

function label = infer_label(imagePath, rootDir)
    [folder, stem, ~] = fileparts(imagePath);
    parentLabel = '';
    folderCanonical = char(java.io.File(char(folder)).getCanonicalPath());

    if ~strcmp(folderCanonical, rootDir)
        [~, parentLabel] = fileparts(folder);
    end

    if isempty(parentLabel) || any(strcmp(parentLabel, {'all', 'train', 'test'}))
        label = regexprep(stem, '\d+$', '');
    else
        label = parentLabel;
    end
end

function value = get_option(options, name, defaultValue)
    if isfield(options, name) && ~isempty(options.(name))
        value = options.(name);
    else
        value = defaultValue;
    end
end
