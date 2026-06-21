function result = action_static_predict(appState, params)
%ACTION_STATIC_PREDICT Train if needed, select one image, and run prediction.

    if nargin < 2 || isempty(params)
        params = struct();
    end

    result = base_result("error", "单张识别未开始。");
    try
        testDir = get_field_or(appState, 'defaultTestDir', fullfile(appState.rootDir, 'data', 'test'));
        [imageData, imagePath, trueName, canceled] = pick_test_image_from_gallery(testDir);
        if canceled
            result.status = "canceled";
            result.message = "已取消单张识别。";
            return;
        end

        model = ensure_recognition_model(appState, params);
        predictResult = predict_face_identity(model, imageData, struct());
        predictResult.trueName = trueName;
        predictResult.imagePath = imagePath;

        appState.model = model;
        appState.singleResult = predictResult;
        appState.currentImage = imageData;
        appState.currentImagePath = imagePath;
        if isfield(predictResult, 'alignedFace') && ~isempty(predictResult.alignedFace)
            appState.currentAlignedFace = predictResult.alignedFace;
        end

        result.status = get_status(predictResult);
        result.message = get_message(predictResult, "单张识别完成。");
        result.appState = appState;
        result.sourceImage = imageData;
        result.faceImage = get_field_or(predictResult, 'alignedFace', []);
        result.singleText = build_single_text(predictResult);
    catch ME
        result.status = "error";
        result.message = "单张识别失败: " + string(ME.message);
    end
end

function [img, imagePath, trueName, canceled] = pick_test_image_from_gallery(testDir)
    img = [];
    imagePath = "";
    trueName = "";
    canceled = true;

    if ~isfolder(testDir)
        error('action_static_predict:MissingTestDir', '默认测试集目录不存在: %s', char(testDir));
    end

    dataset = load_dataset(testDir, struct());
    if ~strcmp(dataset.status, 'ok') || isempty(dataset.records)
        error('action_static_predict:EmptyTestDir', '默认测试集没有可选择的图片: %s', char(testDir));
    end

    selected = select_gallery_record(dataset.records);
    if isempty(selected) || ~isfield(selected, 'imagePath') || isempty(selected.imagePath)
        return;
    end

    imagePath = string(selected.imagePath);
    trueName = string(selected.label);
    img = imread(imagePath);
    canceled = false;
end

function selected = select_gallery_record(records)
    selected = struct();
    cols = 8;
    rows = ceil(numel(records) / cols);

    fig = uifigure('Name', '选择单张测试图识别', ...
        'Position', [80 60 820 720], ...
        'Color', [0.94 0.98 1.00]);
    fig.CloseRequestFcn = @(src, ~) cancel_selection(src);

    root = uigridlayout(fig, [2 1]);
    root.RowHeight = {32, '1x'};
    root.ColumnWidth = {'1x'};
    root.Padding = [8 8 8 8];
    root.RowSpacing = 6;
    root.BackgroundColor = [0.94 0.98 1.00];

    titleLabel = uilabel(root, ...
        'Text', sprintf('测试集人脸照片，共 %d 张。点击任意照片直接识别。', numel(records)), ...
        'FontWeight', 'bold', ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'center');
    titleLabel.Layout.Row = 1;

    panel = uipanel(root, 'BorderType', 'none', 'BackgroundColor', [0.94 0.98 1.00]);
    panel.Layout.Row = 2;
    try
        panel.Scrollable = 'on';
    catch
    end

    grid = uigridlayout(panel, [rows cols]);
    grid.RowHeight = repmat({78}, 1, rows);
    grid.ColumnWidth = repmat({92}, 1, cols);
    grid.Padding = [2 2 2 2];
    grid.RowSpacing = 4;
    grid.ColumnSpacing = 4;
    grid.BackgroundColor = [0.94 0.98 1.00];

    for i = 1:numel(records)
        rec = records(i);
        btn = uibutton(grid, 'push', ...
            'Text', '', ...
            'ButtonPushedFcn', @(~, ~) choose_record(fig, rec));
        btn.Layout.Row = ceil(i / cols);
        btn.Layout.Column = mod(i - 1, cols) + 1;
        try
            btn.WordWrap = 'on';
        catch
        end
        try
            btn.Icon = rec.imagePath;
            btn.IconAlignment = 'center';
        catch
        end
    end

    setappdata(fig, 'SelectedRecord', selected);
    uiwait(fig);

    if isvalid(fig)
        selected = getappdata(fig, 'SelectedRecord');
        delete(fig);
    end
end

function choose_record(fig, rec)
    if isvalid(fig)
        setappdata(fig, 'SelectedRecord', rec);
        uiresume(fig);
    end
end

function cancel_selection(fig)
    if isvalid(fig)
        setappdata(fig, 'SelectedRecord', struct());
        uiresume(fig);
        delete(fig);
    end
end

function textLines = build_single_text(predictResult)
    trueName = string(get_field_or(predictResult, 'trueName', ""));
    name = string(get_field_or(predictResult, 'name', ""));
    topKNames = get_field_or(predictResult, 'topKNames', {});
    topKScores = get_field_or(predictResult, 'topKScores', []);
    elapsedMs = get_field_or(predictResult, 'elapsedMs', []);

    if isempty(name)
        name = "-";
    end
    topKText = format_topk(topKNames, topKScores);
    elapsedText = "-";
    if ~isempty(elapsedMs)
        elapsedText = sprintf('%.2f ms', elapsedMs);
    end
    if strlength(trueName) == 0
        trueName = "-";
    end

    textLines = {
        char("真实姓名: " + trueName)
        char("预测姓名: " + name)
        char("Top-3: " + topKText)
        ['单张耗时: ', elapsedText]
    };
end

function topKText = format_topk(topKNames, topKScores)
    if isempty(topKNames)
        topKText = "-";
        return;
    end
    if isstring(topKNames) || ischar(topKNames)
        names = cellstr(topKNames);
    else
        names = topKNames;
    end
    parts = strings(1, numel(names));
    for i = 1:numel(names)
        if ~isempty(topKScores) && numel(topKScores) >= i
            parts(i) = string(names{i}) + sprintf('(%.3f)', topKScores(i));
        else
            parts(i) = string(names{i});
        end
    end
    topKText = strjoin(parts, ', ');
end

function result = base_result(status, message)
    result = struct('status', status, 'message', message, 'appState', []);
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function status = get_status(s)
    status = string(get_field_or(s, 'status', "ok"));
end

function message = get_message(s, defaultMessage)
    message = string(get_field_or(s, 'message', defaultMessage));
end
