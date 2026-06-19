function result = action_batch_predict(appState, params)
%ACTION_BATCH_PREDICT Run full test-set recognition and prepare GUI table data.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    result = struct('status', "error", 'message', "全量识别未开始。", 'appState', [], ...
        'batchSummaryText', {{}}, 'batchTableData', {cell(0, 5)});

    try
        testDir = pick_test_dir(appState);
        if strlength(testDir) == 0
            result.status = "canceled";
            result.message = "已取消测试集全量识别。";
            return;
        end

        trainDir = get_field_or(appState, 'defaultTrainDir', fullfile(appState.rootDir, 'data', 'train'));
        if ~isfolder(trainDir)
            trainDir = fullfile(appState.rootDir, 'data');
        end
        pcaDim = get_param_or(params, 'pcaDim', appState.defaultPcaDim);
        svmC = get_param_or(params, 'svmC', appState.defaultSvmC);

        model = train_pca_svm_model(trainDir, pcaDim, svmC, struct());
        batchResult = run_batch_test(model, testDir, struct());

        appState.model = model;
        appState.batchResult = batchResult;

        result.status = string(get_field_or(batchResult, 'status', "ok"));
        result.message = string(get_field_or(batchResult, 'message', "测试集全量识别完成。"));
        result.appState = appState;
        result.batchSummaryText = build_batch_summary(batchResult);
        result.batchTableData = build_batch_table(batchResult);
    catch ME
        result.status = "error";
        result.message = "测试集全量识别失败: " + string(ME.message);
    end
end

function testDir = pick_test_dir(appState)
    defaultDir = get_field_or(appState, 'defaultTestDir', fullfile(appState.rootDir, 'data', 'test'));
    if ~isfolder(defaultDir)
        defaultDir = fullfile(appState.rootDir, 'data');
    end
    selected = uigetdir(defaultDir, '选择测试集目录');
    if isequal(selected, 0)
        testDir = "";
    else
        testDir = string(selected);
    end
end

function lines = build_batch_summary(batchResult)
    accuracy = get_field_or(batchResult, 'accuracy', []);
    totalElapsed = get_field_or(batchResult, 'totalElapsedMs', []);
    avgElapsed = get_field_or(batchResult, 'avgElapsedMs', []);

    lines = {
        ['测试集总体准确率: ', format_value(accuracy)]
        ['测试集总耗时: ', format_ms(totalElapsed)]
        ['平均耗时: ', format_ms(avgElapsed)]
    };
end

function tableData = build_batch_table(batchResult)
    rows = get_field_or(batchResult, 'perImageResults', []);
    if isempty(rows)
        tableData = cell(0, 5);
        return;
    end

    if istable(rows)
        tableData = table2cell(rows);
        return;
    end

    if isstruct(rows)
        n = numel(rows);
        tableData = cell(n, 5);
        for i = 1:n
            tableData{i, 1} = get_field_or(rows(i), 'trueName', '');
            tableData{i, 2} = get_field_or(rows(i), 'predName', '');
            tableData{i, 3} = get_field_or(rows(i), 'isCorrect', false);
            tableData{i, 4} = get_field_or(rows(i), 'elapsedMs', []);
            tableData{i, 5} = get_field_or(rows(i), 'imagePath', '');
        end
    else
        tableData = rows;
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
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function text = format_value(value)
    if isempty(value)
        text = '-';
    else
        text = sprintf('%.4g', value);
    end
end

function text = format_ms(value)
    if isempty(value)
        text = '-';
    else
        text = sprintf('%.2f ms', value);
    end
end
