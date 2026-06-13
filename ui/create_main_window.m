function handles = create_main_window(appState, params)
%CREATE_MAIN_WINDOW Build the top-level UI shell.

    %#ok<INUSD>
    fig = uifigure('Name', params.appTitle, 'Position', [100 100 1400 820]);
    tabGroup = uitabgroup(fig, 'Position', [10 10 1380 800]);

    preprocessTab = uitab(tabGroup, 'Title', '图像预处理');
    recognitionTab = uitab(tabGroup, 'Title', '人脸识别');

    handles = struct();
    handles.Figure = fig;
    handles.TabGroup = tabGroup;
    handles.Preprocess = create_preprocess_tab(preprocessTab);
    handles.Recognition = create_recognition_tab(recognitionTab);
end

