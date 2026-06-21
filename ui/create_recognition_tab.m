function handles = create_recognition_tab(parentTab, theme, assets, params)
%CREATE_RECOGNITION_TAB Build the cute three-column recognition workspace.

    if nargin < 2 || isempty(theme)
        theme = get_ui_theme();
    end
    if nargin < 3 || isempty(assets)
        assets = load_ui_assets();
    end
    if nargin < 4 || isempty(params)
        params = default_params();
    end

    handles = struct();
    handles.Parent = parentTab;

    root = uigridlayout(parentTab, [1 3]);
    root.ColumnWidth = theme.layout.columnWidth;
    root.RowHeight = {'1x'};
    root.Padding = theme.layout.padding;
    root.ColumnSpacing = theme.layout.spacing;
    root.BackgroundColor = theme.colors.mistBlue;
    handles.RootGrid = root;

    leftPanel = create_cute_panel(root, 'Recognition Control Block', theme, theme.colors.mintGreen);
    centerPanel = create_cute_panel(root, 'Recognition Display Area', theme, theme.colors.cream);
    rightPanel = create_cute_panel(root, 'Result & Parameter Block', theme, theme.colors.paleSkyBlue);
    handles.LeftPanel = leftPanel;
    handles.CenterPanel = centerPanel;
    handles.RightPanel = rightPanel;

    leftGrid = uigridlayout(leftPanel, [11 2]);
    leftGrid.RowHeight = {32, 32, 40, 40, 40, 40, 40, 40, 44, 116, '1x'};
    leftGrid.ColumnWidth = {'1x', '1x'};
    leftGrid.Padding = [14 18 14 14];
    leftGrid.RowSpacing = 8;
    leftGrid.ColumnSpacing = 10;
    leftGrid.BackgroundColor = theme.colors.mintGreen;

    pcaLabel = uilabel(leftGrid, 'Text', 'PCA 主成分数', 'FontWeight', 'bold', 'FontColor', theme.colors.ink);
    pcaLabel.Layout.Row = 1;
    pcaLabel.Layout.Column = 1;
    handles.PcaDimEdit = uieditfield(leftGrid, 'numeric', 'Value', params.defaultPcaDim, 'Limits', [1 Inf]);
    handles.PcaDimEdit.Layout.Row = 1;
    handles.PcaDimEdit.Layout.Column = 2;

    svmLabel = uilabel(leftGrid, 'Text', 'SVM 正则化 C', 'FontWeight', 'bold', 'FontColor', theme.colors.ink);
    svmLabel.Layout.Row = 2;
    svmLabel.Layout.Column = 1;
    handles.SvmCEdit = uieditfield(leftGrid, 'numeric', 'Value', params.defaultSvmC, 'Limits', [0 Inf]);
    handles.SvmCEdit.Layout.Row = 2;
    handles.SvmCEdit.Layout.Column = 2;

    handles.TrainButton = cuteButton(leftGrid, '训练 / 重新训练模型', theme, 'green', 3, [1 2]);
    handles.BatchTestButton = cuteButton(leftGrid, '测试集全量识别', theme, 'green', 4, [1 2]);
    handles.StaticPredictButton = cuteButton(leftGrid, '选择单张测试图识别', theme, 'green', 5, [1 2]);
    handles.RealtimePredictButton = cuteButton(leftGrid, '实时识别', theme, 'green', 6, [1 2]);
    handles.AverageFaceButton = cuteButton(leftGrid, '显示平均脸', theme, 'green', 7, 1);
    handles.EigenfaceButton = cuteButton(leftGrid, '显示特征脸', theme, 'green', 7, 2);
    handles.ReplayToPreprocessButton = cuteButton(leftGrid, '查看预处理过程', theme, 'green', 8, [1 2]);

    hint = uilabel(leftGrid, ...
        'Text', '验收顺序：全量测试 -> 单张测试 -> 实时采集 -> PCA/SVM 展示', ...
        'WordWrap', 'on', ...
        'FontColor', theme.colors.mutedInk, ...
        'FontWeight', 'bold');
    hint.Layout.Row = 9;
    hint.Layout.Column = [1 2];

    mascotPanel = create_cute_panel(leftGrid, 'Mascot Status', theme, [0.88 1.00 0.78]);
    mascotPanel.Layout.Row = 10;
    mascotPanel.Layout.Column = [1 2];
    mascotGrid = uigridlayout(mascotPanel, [1 2]);
    mascotGrid.ColumnWidth = {92, '1x'};
    mascotGrid.Padding = [10 8 10 10];
    mascotGrid.BackgroundColor = mascotPanel.BackgroundColor;
    handles.MascotControl = uiimage(mascotGrid, 'ImageSource', assets.leftCorner, 'ScaleMethod', 'fit');
    handles.MascotControl.Layout.Column = 1;
    handles.ControlTipText = uitextarea(mascotGrid, ...
        'Value', {'请选择训练集和测试集后开始。', '识别过程中的错误会显示在右侧状态区。'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', theme.colors.cream);
    handles.ControlTipText.Layout.Column = 2;

    centerGrid = uigridlayout(centerPanel, [4 3]);
    centerGrid.RowHeight = {38, '1x', '1x', 50};
    centerGrid.ColumnWidth = {'1x', '1x', '1x'};
    centerGrid.Padding = [14 16 14 14];
    centerGrid.RowSpacing = 12;
    centerGrid.ColumnSpacing = 12;
    centerGrid.BackgroundColor = theme.colors.cream;

    centerTitle = uilabel(centerGrid, ...
        'Text', 'Recognition Display Area', ...
        'FontName', theme.fonts.english, ...
        'FontSize', theme.sizes.title, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.freshGreen, ...
        'HorizontalAlignment', 'center');
    centerTitle.Layout.Row = 1;
    centerTitle.Layout.Column = [1 3];

    handles.SourceAxes = uiaxes(centerGrid);
    handles.SourceAxes.Layout.Row = 2;
    handles.SourceAxes.Layout.Column = 1;
    handles.FaceAxes = uiaxes(centerGrid);
    handles.FaceAxes.Layout.Row = 2;
    handles.FaceAxes.Layout.Column = 2;
    handles.ResultAxes = uiaxes(centerGrid);
    handles.ResultAxes.Layout.Row = 2;
    handles.ResultAxes.Layout.Column = 3;
    initialize_empty_axes(handles.SourceAxes, '输入 / 摄像头', theme);
    initialize_empty_axes(handles.FaceAxes, '识别人脸', theme);
    initialize_empty_axes(handles.ResultAxes, '结果 / 平均脸', theme);

    handles.EigenfaceAxes1 = uiaxes(centerGrid);
    handles.EigenfaceAxes1.Layout.Row = 3;
    handles.EigenfaceAxes1.Layout.Column = 1;
    handles.EigenfaceAxes2 = uiaxes(centerGrid);
    handles.EigenfaceAxes2.Layout.Row = 3;
    handles.EigenfaceAxes2.Layout.Column = 2;
    handles.EigenfaceAxes3 = uiaxes(centerGrid);
    handles.EigenfaceAxes3.Layout.Row = 3;
    handles.EigenfaceAxes3.Layout.Column = 3;
    initialize_empty_axes(handles.EigenfaceAxes1, '特征脸 1', theme);
    initialize_empty_axes(handles.EigenfaceAxes2, '特征脸 2', theme);
    initialize_empty_axes(handles.EigenfaceAxes3, '特征脸 3', theme);

    handles.RecognitionStatusLabel = uilabel(centerGrid, ...
        'Text', '状态：等待训练或选择识别任务。', ...
        'FontName', theme.fonts.body, ...
        'FontSize', 13, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.ink, ...
        'BackgroundColor', theme.colors.mistBlue, ...
        'HorizontalAlignment', 'center');
    handles.RecognitionStatusLabel.Layout.Row = 4;
    handles.RecognitionStatusLabel.Layout.Column = [1 3];

    rightGrid = uigridlayout(rightPanel, [6 2]);
    rightGrid.RowHeight = {126, 108, 136, 176, 132, '1x'};
    rightGrid.ColumnWidth = {'1x', '1x'};
    rightGrid.Padding = [14 18 14 14];
    rightGrid.RowSpacing = 10;
    rightGrid.ColumnSpacing = 10;
    rightGrid.BackgroundColor = theme.colors.paleSkyBlue;

    resultPanel = create_cute_panel(rightGrid, 'single result block', theme, [0.88 0.96 1.00]);
    resultPanel.Layout.Row = 1;
    resultPanel.Layout.Column = [1 2];
    resultGrid = uigridlayout(resultPanel, [1 2]);
    resultGrid.ColumnWidth = {96, '1x'};
    resultGrid.Padding = [10 8 10 10];
    resultGrid.BackgroundColor = resultPanel.BackgroundColor;
    handles.MascotResult = uiimage(resultGrid, 'ImageSource', assets.rightCornerBlue, 'ScaleMethod', 'fit');
    handles.MascotResult.Layout.Column = 1;
    handles.SingleResultText = uitextarea(resultGrid, ...
        'Value', {'真实姓名: -', '预测姓名: -', 'Top-3: -', '单张耗时: -'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', theme.colors.cream);
    handles.SingleResultText.Layout.Column = 2;

    batchPanel = create_cute_panel(rightGrid, 'batch summary block', theme, [0.88 0.96 1.00]);
    batchPanel.Layout.Row = 2;
    batchPanel.Layout.Column = [1 2];
    batchGrid = uigridlayout(batchPanel, [1 1]);
    batchGrid.Padding = [10 8 10 10];
    batchGrid.BackgroundColor = batchPanel.BackgroundColor;
    handles.BatchSummaryText = uitextarea(batchGrid, ...
        'Value', {'测试集总体准确率: -', '测试集总耗时: -', '平均耗时: -'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', theme.colors.cream);

    paramsPanel = create_cute_panel(rightGrid, 'PCA / SVM parameter block', theme, [0.88 0.96 1.00]);
    paramsPanel.Layout.Row = 3;
    paramsPanel.Layout.Column = [1 2];
    paramsGrid = uigridlayout(paramsPanel, [1 1]);
    paramsGrid.Padding = [10 8 10 10];
    paramsGrid.BackgroundColor = paramsPanel.BackgroundColor;
    handles.ParamText = uitextarea(paramsGrid, ...
        'Value', {
            ['PCA 维数: ', char(string(params.defaultPcaDim))]
            ['SVM C: ', char(string(params.defaultSvmC))]
            '模型状态: 未训练'
            ['输入尺寸: ', sprintf('%dx%d', params.imageSize(1), params.imageSize(2))]
        }, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', theme.colors.cream);

    tablePanel = create_cute_panel(rightGrid, 'test result table', theme, theme.colors.cream);
    tablePanel.Layout.Row = 4;
    tablePanel.Layout.Column = [1 2];
    tableGrid = uigridlayout(tablePanel, [1 1]);
    tableGrid.Padding = [8 8 8 8];
    tableGrid.BackgroundColor = tablePanel.BackgroundColor;
    handles.BatchResultTable = uitable(tableGrid, ...
        'Data', cell(0, 5), ...
        'ColumnName', {'真实姓名', '预测姓名', '正确', '耗时ms', '图片路径'});

    realtimePanel = create_cute_panel(rightGrid, 'realtime 10 people block', theme, [0.88 0.96 1.00]);
    realtimePanel.Layout.Row = 5;
    realtimePanel.Layout.Column = [1 2];
    realtimeGrid = uigridlayout(realtimePanel, [1 1]);
    realtimeGrid.Padding = [8 8 8 8];
    realtimeGrid.BackgroundColor = realtimePanel.BackgroundColor;
    handles.RealtimeRecordsTable = uitable(realtimeGrid, ...
        'Data', cell(10, 4), ...
        'ColumnName', {'序号', '识别来源', '识别结果', '备注'});

    statusPanel = create_cute_panel(rightGrid, 'status log', theme, theme.colors.cream);
    statusPanel.Layout.Row = 6;
    statusPanel.Layout.Column = [1 2];
    statusGrid = uigridlayout(statusPanel, [1 1]);
    statusGrid.Padding = [8 8 8 8];
    statusGrid.BackgroundColor = statusPanel.BackgroundColor;
    handles.StatusLogText = uitextarea(statusGrid, ...
        'Value', {'等待操作。'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', [1 1 1]);
end

function btn = cuteButton(parent, text, theme, variant, row, col)
    btn = uibutton(parent, 'push', 'Text', text);
    btn.Layout.Row = row;
    btn.Layout.Column = col;
    apply_cute_button_style(btn, theme, variant);
end
