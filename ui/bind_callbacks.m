function bind_callbacks(handles)
%BIND_CALLBACKS Attach GUI callbacks after UI creation.

    pre = handles.Preprocess;
    rec = handles.Recognition;

    pre.ImportButton.ButtonPushedFcn = @(~, ~) on_import_image(handles);
    pre.ClearButton.ButtonPushedFcn = @(~, ~) on_clear_image(handles);
    pre.GrayButton.ButtonPushedFcn = @(~, ~) on_gray_image(handles);
    pre.EqualizeButton.ButtonPushedFcn = @(~, ~) on_equalize_image(handles);
    pre.StatsButton.ButtonPushedFcn = @(~, ~) on_image_stats(handles);
    pre.HistogramButton.ButtonPushedFcn = @(~, ~) on_histogram(handles);
    pre.ScaleButton.ButtonPushedFcn = @(~, ~) on_scale_image(handles);
    pre.RotateButton.ButtonPushedFcn = @(~, ~) on_rotate_image(handles);
    pre.FaceSelectButton.ButtonPushedFcn = @(~, ~) on_detect_face(handles);
    pre.FaceAlignButton.ButtonPushedFcn = @(~, ~) on_align_face(handles);
    pre.StartCameraButton.ButtonPushedFcn = @(~, ~) on_start_camera(handles);
    pre.StopCameraButton.ButtonPushedFcn = @(~, ~) on_stop_camera(handles);
    pre.TransformPreviewButton.ButtonPushedFcn = @(~, ~) set_pre_status(handles, '状态：可通过右侧参数按钮展示平移、缩放、旋转等几何运算。');

    rec.TrainButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '训练 / 重新训练模型', @action_static_predict);
    rec.BatchTestButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '测试集全量识别', @action_batch_predict);
    rec.StaticPredictButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '选择单张测试图识别', @action_static_predict);
    rec.RealtimePredictButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '实时识别', @action_realtime_predict);
    rec.StopRealtimeButton.ButtonPushedFcn = @(~, ~) set_rec_status(handles, '状态：实时识别已请求停止。');
    rec.AverageFaceButton.ButtonPushedFcn = @(~, ~) on_average_face(handles);
    rec.EigenfaceButton.ButtonPushedFcn = @(~, ~) on_eigenfaces(handles);
    rec.PreprocessCompareButton.ButtonPushedFcn = @(~, ~) set_rec_status(handles, "状态：创新小项目策略 = " + string(rec.CompareModeDropDown.Value));
    rec.ReplayToPreprocessButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '送入预处理页复现', @action_replay_to_preprocess);
end

function on_import_image(handles)
    [img, imagePath] = import_image();
    if isempty(img)
        set_pre_status(handles, '状态：已取消输入图像。');
        return;
    end

    state = get_state(handles);
    state.currentImage = img;
    state.currentImagePath = imagePath;
    state.currentGrayImage = [];
    state.currentProcessedImage = [];
    state.currentFaceInfo = struct();
    state.currentAlignInfo = struct();
    state.currentAlignedFace = [];
    set_state(handles, state);

    update_axes_image(handles.Preprocess.InputAxes, img, '原始图像');
    initialize_empty_axes(handles.Preprocess.ProcessedAxes, '处理后图像');
    refresh_image_info(handles, img, "已输入图像: " + imagePath);
end

function on_clear_image(handles)
    state = get_state(handles);
    state = clear_image_state(state);
    set_state(handles, state);

    cla(handles.Preprocess.InputAxes);
    cla(handles.Preprocess.ProcessedAxes);
    initialize_empty_axes(handles.Preprocess.InputAxes, '拍摄 / 输入原图');
    initialize_empty_axes(handles.Preprocess.ProcessedAxes, '处理后图像');
    handles.Preprocess.StatsText.Value = {'最大灰度值: -', '最小灰度值: -', '灰度均值: -', '灰度值方差: -'};
    handles.Preprocess.InfoText.Value = {'尺寸: -', '通道数: -', '捕获时间: -', '当前状态: 已清除图像'};
    set_pre_status(handles, '状态：图像已清除。');
end

function on_gray_image(handles)
    state = get_state(handles);
    if isempty(state.currentImage)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    grayImg = convert_to_gray(state.currentImage);
    state.currentGrayImage = grayImg;
    state.currentProcessedImage = grayImg;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, grayImg, '灰度图像');
    refresh_image_info(handles, grayImg, '已完成灰度变换。');
end

function on_equalize_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    eqImg = equalize_image(img);
    state.currentGrayImage = eqImg;
    state.currentProcessedImage = eqImg;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, eqImg, '均衡化图像');
    refresh_image_info(handles, eqImg, '已完成直方图均衡化。');
end

function on_image_stats(handles)
    state = get_state(handles);
    img = current_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    stats = compute_image_stats(convert_to_gray(img));
    handles.Preprocess.StatsText.Value = {
        sprintf('最大灰度值: %.4g', stats.maxVal)
        sprintf('最小灰度值: %.4g', stats.minVal)
        sprintf('灰度均值: %.4f', stats.meanVal)
        sprintf('灰度值方差: %.4f', stats.varVal)
    };
    set_pre_status(handles, '状态：图像参数已刷新。');
end

function on_histogram(handles)
    state = get_state(handles);
    img = current_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    fig = uifigure('Name', '灰度直方图', 'Position', [180 120 640 420]);
    ax = uiaxes(fig, 'Position', [30 40 580 340]);
    draw_histogram(img, ax);
    title(ax, '灰度直方图');
    set_pre_status(handles, '状态：灰度直方图已绘制。');
end

function on_scale_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    factor = str2double(handles.Preprocess.ScaleEdit.Value);
    if isempty(img) || isnan(factor) || factor <= 0
        set_pre_status(handles, '状态：请先输入图像，并填写大于 0 的缩放倍率。');
        return;
    end

    outImg = scale_image(img, factor);
    state.currentGrayImage = outImg;
    state.currentProcessedImage = outImg;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('缩放 %.2fx', factor));
    refresh_image_info(handles, outImg, sprintf('已完成图像缩放 %.2fx。', factor));
end

function on_rotate_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    angle = str2double(handles.Preprocess.RotateEdit.Value);
    if isempty(img) || isnan(angle)
        set_pre_status(handles, '状态：请先输入图像，并填写旋转角度。');
        return;
    end

    outImg = rotate_image(img, angle);
    state.currentGrayImage = outImg;
    state.currentProcessedImage = outImg;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('旋转 %.1f°', angle));
    refresh_image_info(handles, outImg, sprintf('已完成图像旋转 %.1f 度。', angle));
end

function on_start_camera(handles)
    state = get_state(handles);
    [cam, message] = camera_start();
    if isempty(cam)
        set_pre_status(handles, "状态：" + message);
        return;
    end

    [frame, snapMessage] = camera_snapshot(cam);
    state.camera = cam;
    if ~isempty(frame)
        state.currentCameraFrame = frame;
        state.currentImage = frame;
        state.currentImagePath = "camera";
        state.currentGrayImage = [];
        state.currentProcessedImage = [];
        update_axes_image(handles.Preprocess.InputAxes, frame, '拍摄 / 输入原图');
        initialize_empty_axes(handles.Preprocess.ProcessedAxes, '处理后图像');
        refresh_image_info(handles, frame, snapMessage);
    else
        set_pre_status(handles, "状态：" + message + " " + snapMessage);
    end
    set_state(handles, state);
end

function on_stop_camera(handles)
    state = get_state(handles);
    message = camera_stop(get_optional_field(state, 'camera', []));
    state.camera = [];
    set_state(handles, state);
    set_pre_status(handles, "状态：" + message);
end

function on_detect_face(handles)
    state = get_state(handles);
    img = original_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像或启动摄像头。');
        return;
    end

    faceInfo = detect_face(img, struct());
    state.currentFaceInfo = faceInfo;
    state.currentFaceBox = faceInfo.faceBox;
    if isfield(faceInfo, 'faceImage') && ~isempty(faceInfo.faceImage)
        state.currentProcessedImage = faceInfo.faceImage;
        update_axes_image(handles.Preprocess.ProcessedAxes, faceInfo.faceImage, '检测到的人脸');
    end
    set_state(handles, state);

    update_axes_image(handles.Preprocess.InputAxes, img, '拍摄 / 输入原图');
    if string(faceInfo.status) == "ok" && ~isempty(faceInfo.faceBox)
        hold(handles.Preprocess.InputAxes, 'on');
        rectangle('Parent', handles.Preprocess.InputAxes, ...
            'Position', faceInfo.faceBox, ...
            'EdgeColor', 'r', ...
            'LineWidth', 2);
        hold(handles.Preprocess.InputAxes, 'off');
    end
    set_pre_status(handles, "状态：" + string(faceInfo.message));
end

function on_align_face(handles)
    state = get_state(handles);
    img = original_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像或启动摄像头。');
        return;
    end

    faceInfo = get_optional_field(state, 'currentFaceInfo', struct());
    if isempty(fieldnames(faceInfo)) || ~isfield(faceInfo, 'faceImage') || isempty(faceInfo.faceImage)
        faceInfo = detect_face(img, struct());
        state.currentFaceInfo = faceInfo;
        state.currentFaceBox = faceInfo.faceBox;
    end

    options = struct('imageSize', [112, 92]);
    alignInfo = align_face(img, faceInfo, options);
    state.currentAlignInfo = alignInfo;
    if isfield(alignInfo, 'alignedFace') && ~isempty(alignInfo.alignedFace)
        state.currentAlignedFace = alignInfo.alignedFace;
        state.currentProcessedImage = alignInfo.alignedFace;
        update_axes_image(handles.Preprocess.ProcessedAxes, alignInfo.alignedFace, '校准后人脸');
    end
    set_state(handles, state);
    set_pre_status(handles, "状态：" + string(alignInfo.message));
end

function on_recognition_action(handles, actionName, actionFcn)
    state = get_state(handles);
    params = struct();
    params.pcaDim = handles.Recognition.PcaDimEdit.Value;
    params.svmC = handles.Recognition.SvmCEdit.Value;

    result = actionFcn(state, params);
    message = "状态：" + string(actionName) + " 已触发";
    if isfield(result, 'status')
        message = message + "，接口返回 " + string(result.status);
    end
    if isfield(result, 'message') && strlength(string(result.message)) > 0
        message = message + "：" + string(result.message);
    end

    apply_recognition_result(handles, result, actionName);
    set_rec_status(handles, message + "。");
    append_status_log(handles, message);
end

function apply_recognition_result(handles, result, actionName)
    if isfield(result, 'appState') && isstruct(result.appState) && ~isempty(result.appState)
        set_state(handles, result.appState);
    end

    if isfield(result, 'sourceImage') && ~isempty(result.sourceImage)
        update_axes_image(handles.Recognition.SourceAxes, result.sourceImage, '输入 / 摄像头');
    end
    if isfield(result, 'faceImage') && ~isempty(result.faceImage)
        update_axes_image(handles.Recognition.FaceAxes, result.faceImage, '识别人脸');
    end
    if string(actionName) == "送入预处理页复现" && ...
            isfield(result, 'rawFrame') && ~isempty(result.rawFrame)
        handles.TabGroup.SelectedTab = handles.Preprocess.Parent;
        update_axes_image(handles.Preprocess.InputAxes, result.rawFrame, '拍摄 / 输入原图');
        if isfield(result, 'alignedFace') && ~isempty(result.alignedFace)
            update_axes_image(handles.Preprocess.ProcessedAxes, result.alignedFace, '处理后图像');
        end
        refresh_image_info(handles, result.rawFrame, result.message);
    end
    if isfield(result, 'singleText') && ~isempty(result.singleText)
        handles.Recognition.SingleResultText.Value = result.singleText;
    end
    if isfield(result, 'batchSummaryText') && ~isempty(result.batchSummaryText)
        handles.Recognition.BatchSummaryText.Value = result.batchSummaryText;
    end
    if isfield(result, 'batchTableData') && ~isempty(result.batchTableData)
        update_result_table(handles.Recognition.BatchResultTable, result.batchTableData);
    end
end

function on_average_face(handles)
    state = get_state(handles);
    if ~isfield(state, 'model') || isempty(state.model)
        set_rec_status(handles, '状态：请先训练或运行一次识别。');
        return;
    end

    try
        avgFace = build_average_face(state.model);
        if isempty(avgFace)
            set_rec_status(handles, '状态：平均脸接口尚未返回图像。');
            return;
        end
        update_axes_image(handles.Recognition.ResultAxes, avgFace, '平均脸');
        set_rec_status(handles, '状态：平均脸已显示。');
    catch ME
        set_rec_status(handles, "状态：平均脸显示失败: " + string(ME.message));
    end
end

function on_eigenfaces(handles)
    state = get_state(handles);
    if ~isfield(state, 'model') || isempty(state.model)
        set_rec_status(handles, '状态：请先训练或运行一次识别。');
        return;
    end

    try
        eigenfaces = build_eigenface_preview(state.model, 3);
        axesList = {handles.Recognition.EigenfaceAxes1, handles.Recognition.EigenfaceAxes2, handles.Recognition.EigenfaceAxes3};
        shown = 0;
        for i = 1:min(numel(eigenfaces), 3)
            if ~isempty(eigenfaces{i})
                update_axes_image(axesList{i}, eigenfaces{i}, sprintf('特征脸 %d', i));
                shown = shown + 1;
            end
        end
        if shown == 0
            set_rec_status(handles, '状态：特征脸接口尚未返回图像。');
        else
            set_rec_status(handles, '状态：特征脸已显示。');
        end
    catch ME
        set_rec_status(handles, "状态：特征脸显示失败: " + string(ME.message));
    end
end

function refresh_image_info(handles, img, statusMessage)
    dims = size(img);
    if numel(dims) < 3
        channels = 1;
    else
        channels = dims(3);
    end
    handles.Preprocess.InfoText.Value = {
        sprintf('尺寸: %d x %d', dims(2), dims(1))
        sprintf('通道数: %d', channels)
        ['捕获时间: ', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))]
        ['当前状态: ', char(statusMessage)]
    };
    set_pre_status(handles, ['状态：', char(statusMessage)]);
end

function img = current_source_image(state)
    if isfield(state, 'currentProcessedImage') && ~isempty(state.currentProcessedImage)
        img = state.currentProcessedImage;
    elseif isfield(state, 'currentGrayImage') && ~isempty(state.currentGrayImage)
        img = state.currentGrayImage;
    elseif isfield(state, 'currentImage') && ~isempty(state.currentImage)
        img = state.currentImage;
    else
        img = [];
    end
end

function img = original_source_image(state)
    if isfield(state, 'currentCameraFrame') && ~isempty(state.currentCameraFrame)
        img = state.currentCameraFrame;
    elseif isfield(state, 'currentImage') && ~isempty(state.currentImage)
        img = state.currentImage;
    else
        img = [];
    end
end

function value = get_optional_field(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function set_pre_status(handles, message)
    handles.Preprocess.StatusLabel.Text = char(message);
end

function set_rec_status(handles, message)
    handles.Recognition.RecognitionStatusLabel.Text = char(message);
end

function append_status_log(handles, message)
    oldValue = handles.Recognition.StatusLogText.Value;
    handles.Recognition.StatusLogText.Value = [oldValue; {char(message)}];
end

function state = get_state(handles)
    state = handles.Figure.UserData;
end

function set_state(handles, state)
    handles.Figure.UserData = state;
end
