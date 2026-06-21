function result = action_batch_predict(appState, params)
%ACTION_BATCH_PREDICT Run full test-set recognition and prepare GUI table data.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    result = struct('status', "error", 'message', "全量识别未开始。", 'appState', [], ...
        'batchSummaryText', {{}}, 'batchTableData', {cell(0, 5)});

    try
        testDir = default_test_dir(appState);
        if strlength(testDir) == 0
            result.status = "missing_test_dir";
            result.message = "未找到默认测试集目录。";
            return;
        end

        model = ensure_recognition_model(appState, params);
        batchResult = run_batch_test(model, testDir, struct());

        appState.model = model;
        appState.batchResult = batchResult;

        result.status = string(get_field_or(batchResult, 'status', "ok"));
        result.message = string(get_field_or(batchResult, 'message', "测试集全量识别完成。"));
        result.appState = appState;
        result.batchSummaryText = build_batch_summary(batchResult);
        result.batchTableData = build_batch_table(batchResult, testDir);
    catch ME
        result.status = "error";
        result.message = "测试集全量识别失败: " + string(ME.message);
    end
end

function testDir = default_test_dir(appState)
    defaultDir = get_field_or(appState, 'defaultTestDir', fullfile(appState.rootDir, 'data', 'test'));
    if ~isfolder(defaultDir)
        testDir = "";
    else
        testDir = string(defaultDir);
    end
end

function lines = build_batch_summary(batchResult)
    accuracy = get_field_or(batchResult, 'accuracy', []);
    totalElapsed = get_field_or(batchResult, 'totalElapsedMs', []);
    avgElapsed = get_field_or(batchResult, 'avgElapsedMs', []);

    lines = {
        ['测试集总体准确率: ', format_accuracy(accuracy, batchResult)]
        ['测试集总耗时: ', format_ms(totalElapsed)]
        ['平均耗时: ', format_ms(avgElapsed)]
    };
end

function tableData = build_batch_table(batchResult, testDir)
    rows = get_field_or(batchResult, 'perImageResults', []);
    if isempty(rows)
        tableData = cell(0, 5);
        return;
    end

    summaryRow = {
        '测试集准确率', ...
        format_accuracy(get_field_or(batchResult, 'accuracy', []), batchResult), ...
        '', ...
        format_ms(get_field_or(batchResult, 'totalElapsedMs', [])), ...
        char(testDir)
    };

    if istable(rows)
        tableData = [summaryRow; table2cell(rows)];
        return;
    end

    if isstruct(rows)
        n = numel(rows);
        tableData = cell(n + 1, 5);
        tableData(1, :) = summaryRow;
        for i = 1:n
            tableData{i + 1, 1} = get_field_or(rows(i), 'trueName', '');
            tableData{i + 1, 2} = get_field_or(rows(i), 'predName', '');
            tableData{i + 1, 3} = get_field_or(rows(i), 'isCorrect', false);
            tableData{i + 1, 4} = get_field_or(rows(i), 'elapsedMs', []);
            tableData{i + 1, 5} = get_field_or(rows(i), 'imagePath', '');
        end
    else
        tableData = [summaryRow; rows];
    end
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function text = format_accuracy(value, batchResult)
    if isempty(value)
        text = '-';
    else
        rows = get_field_or(batchResult, 'perImageResults', []);
        if isstruct(rows) && ~isempty(rows)
            correctCount = sum([rows.isCorrect]);
            totalCount = numel(rows);
            text = sprintf('%.2f%% (%d/%d)', value * 100, correctCount, totalCount);
        else
            text = sprintf('%.2f%%', value * 100);
        end
    end
end

function text = format_ms(value)
    if isempty(value)
        text = '-';
    else
        text = sprintf('%.2f ms', value);
    end
end
