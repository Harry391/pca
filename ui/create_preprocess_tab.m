function handles = create_preprocess_tab(parentTab, theme, assets)
%CREATE_PREPROCESS_TAB Build the cute three-column preprocess workspace.

    if nargin < 2 || isempty(theme)
        theme = get_ui_theme();
    end
    if nargin < 3 || isempty(assets)
        assets = load_ui_assets();
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

    leftPanel = create_cute_panel(root, 'Main Function Block', theme, theme.colors.mintGreen);
    centerPanel = create_cute_panel(root, 'Image Display Area', theme, theme.colors.cream);
    rightPanel = create_cute_panel(root, 'ImgProcessing Toolbox', theme, theme.colors.paleSkyBlue);
    handles.LeftPanel = leftPanel;
    handles.CenterPanel = centerPanel;
    handles.RightPanel = rightPanel;

    leftGrid = uigridlayout(leftPanel, [5 2]);
    leftGrid.RowHeight = {42, 42, 42, 220, '1x'};
    leftGrid.ColumnWidth = {'1x', '1x'};
    leftGrid.Padding = [14 18 14 14];
    leftGrid.RowSpacing = 12;
    leftGrid.ColumnSpacing = 12;
    leftGrid.BackgroundColor = theme.colors.mintGreen;

    handles.ImportButton = cuteButton(leftGrid, '输入图像', theme, 'green', 1, 1);
    handles.ClearButton = cuteButton(leftGrid, '清除图像', theme, 'green', 1, 2);
    handles.GrayButton = cuteButton(leftGrid, '灰度化', theme, 'green', 2, 1);
    handles.EqualizeButton = cuteButton(leftGrid, '均衡化', theme, 'green', 2, 2);
    handles.StartCameraButton = cuteButton(leftGrid, '启动摄像头', theme, 'green', 3, 1);
    handles.StopCameraButton = cuteButton(leftGrid, '停止摄像头', theme, 'green', 3, 2);

    decorationPanel = uipanel(leftGrid, ...
        'BackgroundColor', [0.68 0.92 0.67], ...
        'BorderType', 'line', ...
        'BorderColor', theme.colors.panelLine);
    decorationPanel.Layout.Row = 4;
    decorationPanel.Layout.Column = [1 2];
    decorationGrid = uigridlayout(decorationPanel, [1 1]);
    decorationGrid.Padding = [0 0 0 0];
    decorationGrid.BackgroundColor = decorationPanel.BackgroundColor;
    handles.MascotInfo = uiimage(decorationGrid, 'ImageSource', assets.leftCorner, 'ScaleMethod', 'fit');

    infoPanel = create_cute_panel(leftGrid, 'Image Info Block', theme, [0.68 0.92 0.67]);
    infoPanel.Layout.Row = 5;
    infoPanel.Layout.Column = [1 2];
    infoGrid = uigridlayout(infoPanel, [1 1]);
    infoGrid.RowHeight = {'1x'};
    infoGrid.Padding = [10 8 10 10];
    infoGrid.BackgroundColor = infoPanel.BackgroundColor;
    handles.InfoText = uitextarea(infoGrid, ...
        'Value', {'尺寸: -', '通道数: -', '捕获时间: -', '当前状态: 等待输入'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'FontSize', theme.sizes.small, ...
        'BackgroundColor', theme.colors.cream);
    handles.InfoText.Layout.Row = 1;

    centerGrid = uigridlayout(centerPanel, [3 2]);
    centerGrid.RowHeight = {46, '1x', 46};
    centerGrid.ColumnWidth = {'1x', '1x'};
    centerGrid.Padding = [14 16 14 14];
    centerGrid.RowSpacing = 12;
    centerGrid.ColumnSpacing = 12;
    centerGrid.BackgroundColor = theme.colors.cream;

    centerTitle = uilabel(centerGrid, ...
        'Text', 'Image Display Area', ...
        'FontName', theme.fonts.english, ...
        'FontSize', theme.sizes.title, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.freshGreen, ...
        'HorizontalAlignment', 'center');
    centerTitle.Layout.Row = 1;
    centerTitle.Layout.Column = [1 2];

    handles.InputAxes = uiaxes(centerGrid);
    handles.InputAxes.Layout.Row = 2;
    handles.InputAxes.Layout.Column = 1;
    handles.ProcessedAxes = uiaxes(centerGrid);
    handles.ProcessedAxes.Layout.Row = 2;
    handles.ProcessedAxes.Layout.Column = 2;
    initialize_empty_axes(handles.InputAxes, '拍摄 / 输入原图', theme);
    initialize_empty_axes(handles.ProcessedAxes, '处理后图像', theme);

    handles.StatusLabel = uilabel(centerGrid, ...
        'Text', '状态：请先输入图像或启动摄像头。', ...
        'FontName', theme.fonts.body, ...
        'FontSize', 13, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.ink, ...
        'BackgroundColor', theme.colors.mistBlue, ...
        'HorizontalAlignment', 'center');
    handles.StatusLabel.Layout.Row = 3;
    handles.StatusLabel.Layout.Column = [1 2];

    rightGrid = uigridlayout(rightPanel, [6 2]);
    rightGrid.RowHeight = {48, 190, 52, 52, 230, '1x'};
    rightGrid.ColumnWidth = {'1x', '1x'};
    rightGrid.Padding = [14 18 14 14];
    rightGrid.RowSpacing = 12;
    rightGrid.ColumnSpacing = 12;
    rightGrid.BackgroundColor = theme.colors.paleSkyBlue;

    handles.StatsButton = cuteButton(rightGrid, '获取图像参数', theme, 'blue', 1, 1);
    handles.HistogramButton = cuteButton(rightGrid, '绘制灰度直方图', theme, 'blue', 1, 2);

    parameterPanel = create_cute_panel(rightGrid, 'image parameter block', theme, theme.colors.paleSkyBlue);
    parameterPanel.Layout.Row = 2;
    parameterPanel.Layout.Column = [1 2];
    parameterGrid = uigridlayout(parameterPanel, [1 2]);
    parameterGrid.ColumnWidth = {180, '1x'};
    parameterGrid.Padding = [10 8 10 10];
    parameterGrid.BackgroundColor = parameterPanel.BackgroundColor;
    handles.MascotParams = uiimage(parameterGrid, 'ImageSource', assets.rightCornerBlue, 'ScaleMethod', 'fit');
    handles.MascotParams.Layout.Column = 1;
    handles.StatsText = uitextarea(parameterGrid, ...
        'Value', {'最大灰度值: -', '最小灰度值: -', '灰度均值: -', '灰度值方差: -'}, ...
        'Editable', 'off', ...
        'FontName', theme.fonts.body, ...
        'BackgroundColor', theme.colors.cream);
    handles.StatsText.Layout.Column = 2;

    handles.FaceAlignButton = cuteButton(rightGrid, '人脸校准', theme, 'blue', 3, 1);
    handles.FaceSelectButton = cuteButton(rightGrid, '人脸框选', theme, 'blue', 3, 2);
    handles.TransformPreviewButton = cuteButton(rightGrid, '人脸检测', theme, 'blue', 4, [1 2]);

    transformPanel = create_cute_panel(rightGrid, 'image transform block', theme, [0.88 0.96 1.00]);
    transformPanel.Layout.Row = 5;
    transformPanel.Layout.Column = [1 2];
    transformGrid = uigridlayout(transformPanel, [6 3]);
    transformGrid.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x'};
    transformGrid.ColumnWidth = {'1x', 70, 90};
    transformGrid.Padding = [10 8 10 10];
    transformGrid.RowSpacing = 8;
    transformGrid.BackgroundColor = transformPanel.BackgroundColor;

    handles.TranslateButton = cuteButton(transformGrid, '图像平移', theme, 'blue', 1, 1);
    handles.TranslateEdit = editField(transformGrid, '0,0', 1);
    handles.ScaleButton = cuteButton(transformGrid, '图像缩放', theme, 'blue', 2, 1);
    handles.ScaleEdit = editField(transformGrid, '1.0', 2);
    handles.ShearButton = cuteButton(transformGrid, '图像切变', theme, 'blue', 3, 1);
    handles.ShearEdit = editField(transformGrid, '0.0', 3);
    handles.RotateButton = cuteButton(transformGrid, '图像旋转', theme, 'blue', 4, 1);
    handles.RotateEdit = editField(transformGrid, '0', 4);
    handles.BrightnessButton = cuteButton(transformGrid, '图像亮度', theme, 'blue', 5, 1);
    handles.BrightnessEdit = editField(transformGrid, '0', 5);
    handles.RestoreButton = cuteButton(transformGrid, '恢复原图', theme, 'blue', 6, [1 3]);

    handles.HorizontalFlipButton = cuteButton(rightGrid, '水平翻转', theme, 'blue', 6, 1);
    handles.VerticalFlipButton = cuteButton(rightGrid, '垂直翻转', theme, 'blue', 6, 2);
end

function btn = cuteButton(parent, text, theme, variant, row, col)
    btn = uibutton(parent, 'push', 'Text', text);
    btn.Layout.Row = row;
    btn.Layout.Column = col;
    apply_cute_button_style(btn, theme, variant);
end

function field = editField(parent, value, row)
    label = uilabel(parent, 'Text', '参数', 'HorizontalAlignment', 'center');
    label.Layout.Row = row;
    label.Layout.Column = 2;
    field = uieditfield(parent, 'text', 'Value', value);
    field.Layout.Row = row;
    field.Layout.Column = 3;
end
