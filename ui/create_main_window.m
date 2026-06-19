function handles = create_main_window(appState, params, theme, assets)
%CREATE_MAIN_WINDOW Build the top-level UI shell.

    %#ok<INUSD>
    if nargin < 3 || isempty(theme)
        theme = get_ui_theme();
    end
    if nargin < 4 || isempty(assets)
        assets = load_ui_assets();
    end

    fig = uifigure( ...
        'Name', params.appTitle, ...
        'Position', theme.layout.windowPosition, ...
        'Color', theme.colors.mistBlue);

    rootGrid = uigridlayout(fig, [2 1]);
    rootGrid.RowHeight = {54, '1x'};
    rootGrid.ColumnWidth = {'1x'};
    rootGrid.Padding = [10 10 10 10];
    rootGrid.RowSpacing = 8;

    header = uigridlayout(rootGrid, [1 4]);
    header.Layout.Row = 1;
    header.ColumnWidth = {70, '1x', 210, 70};
    header.Padding = [4 0 4 0];
    header.BackgroundColor = theme.colors.mistBlue;

    leftMascot = uiimage(header, 'ImageSource', assets.idle, 'ScaleMethod', 'fit');
    leftMascot.Layout.Column = 1;

    titleLabel = uilabel(header, ...
        'Text', '小八 Face Lab', ...
        'FontName', theme.fonts.body, ...
        'FontSize', 28, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.brightBlue, ...
        'HorizontalAlignment', 'center');
    titleLabel.Layout.Column = 2;

    subtitle = uilabel(header, ...
        'Text', 'PCA + SVM 验收演示版', ...
        'FontName', theme.fonts.body, ...
        'FontSize', 13, ...
        'FontWeight', 'bold', ...
        'FontColor', theme.colors.mutedInk, ...
        'HorizontalAlignment', 'right');
    subtitle.Layout.Column = 3;

    rightMascot = uiimage(header, 'ImageSource', assets.helper, 'ScaleMethod', 'fit');
    rightMascot.Layout.Column = 4;

    tabGroup = uitabgroup(rootGrid);
    tabGroup.Layout.Row = 2;

    preprocessTab = uitab(tabGroup, 'Title', '图像预处理');
    recognitionTab = uitab(tabGroup, 'Title', '人脸识别');
    preprocessTab.BackgroundColor = theme.colors.mistBlue;
    recognitionTab.BackgroundColor = theme.colors.mistBlue;

    handles = struct();
    handles.Figure = fig;
    handles.TabGroup = tabGroup;
    handles.Theme = theme;
    handles.Assets = assets;
    handles.Preprocess = create_preprocess_tab(preprocessTab, theme, assets);
    handles.Recognition = create_recognition_tab(recognitionTab, theme, assets, params);
end

