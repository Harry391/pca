function bind_callbacks(handles)
%BIND_CALLBACKS Attach GUI callbacks after UI creation.

    pre = handles.Preprocess;
    rec = handles.Recognition;

    handles.Figure.CloseRequestFcn = @(src, ~) on_close_figure(handles, src);

    pre.ImportButton.ButtonPushedFcn = @(~, ~) on_import_image(handles);
    pre.ClearButton.ButtonPushedFcn = @(~, ~) on_clear_image(handles);
    pre.GrayButton.ButtonPushedFcn = @(~, ~) on_gray_image(handles);
    pre.EqualizeButton.ButtonPushedFcn = @(~, ~) on_equalize_image(handles);
    pre.StatsButton.ButtonPushedFcn = @(~, ~) on_image_stats(handles);
    pre.HistogramButton.ButtonPushedFcn = @(~, ~) on_histogram(handles);
    pre.TranslateButton.ButtonPushedFcn = @(~, ~) on_translate_image(handles);
    pre.ScaleButton.ButtonPushedFcn = @(~, ~) on_scale_image(handles);
    pre.ShearButton.ButtonPushedFcn = @(~, ~) on_shear_image(handles);
    pre.RotateButton.ButtonPushedFcn = @(~, ~) on_rotate_image(handles);
    pre.BrightnessButton.ButtonPushedFcn = @(~, ~) on_brightness_image(handles);
    pre.RestoreButton.ButtonPushedFcn = @(~, ~) on_restore_original_image(handles);
    pre.HorizontalFlipButton.ButtonPushedFcn = @(~, ~) on_flip_image(handles, 'horizontal');
    pre.VerticalFlipButton.ButtonPushedFcn = @(~, ~) on_flip_image(handles, 'vertical');
    pre.FaceSelectButton.ButtonPushedFcn = @(~, ~) on_manual_select_face(handles);
    pre.FaceAlignButton.ButtonPushedFcn = @(~, ~) on_align_face(handles);
    pre.StartCameraButton.ButtonPushedFcn = @(~, ~) on_start_camera(handles);
    pre.StopCameraButton.ButtonPushedFcn = @(~, ~) on_stop_camera(handles);
    pre.TransformPreviewButton.ButtonPushedFcn = @(~, ~) on_detect_face(handles);

    rec.TrainButton.ButtonPushedFcn = @(~, ~) on_train_model(handles);
    rec.BatchTestButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '测试集全量识别', @action_batch_predict);
    rec.StaticPredictButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '选择单张测试图识别', @action_static_predict);
    rec.RealtimePredictButton.ButtonPushedFcn = @(~, ~) on_try_realtime_recognition(handles);
    rec.AverageFaceButton.ButtonPushedFcn = @(~, ~) on_average_face(handles);
    rec.EigenfaceButton.ButtonPushedFcn = @(~, ~) on_eigenfaces(handles);
    rec.ReplayToPreprocessButton.ButtonPushedFcn = @(~, ~) on_recognition_action(handles, '查看预处理过程', @action_replay_to_preprocess);
end

function on_import_image(handles)
    [img, imagePath] = import_image();
    if isempty(img)
        set_pre_status(handles, '状态：已取消输入图像。');
        return;
    end

    state = get_state(handles);
    state = stop_manual_face_roi(state);
    state.currentImage = img;
    state.currentImagePath = imagePath;
    state.currentPreprocessBaseImage = img;
    state.currentPreprocessBaseLabel = "左侧输入原图";
    state.currentRestoreImage = img;
    state.currentRestoreLabel = "左侧输入原图";
    state.currentGrayImage = [];
    state.currentProcessedImage = [];
    state.currentFaceInfo = struct();
    state.currentFaceRoi = [];
    state.currentFaceRoiListeners = [];
    state.currentAlignInfo = struct();
    state.currentAlignedFace = [];
    state = clear_service_preprocess_mode(state);
    set_state(handles, state);

    update_axes_image(handles.Preprocess.InputAxes, img, '原始图像');
    initialize_empty_axes(handles.Preprocess.ProcessedAxes, '处理后图像');
    refresh_image_info(handles, img, "已输入图像: " + imagePath);
end

function on_clear_image(handles)
    state = get_state(handles);
    state = stop_manual_face_roi(state);
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
    if is_service_preprocess_state(state) && isfield(state, 'serviceGrayFace') && ~isempty(state.serviceGrayFace)
        grayImg = state.serviceGrayFace;
        sourceLabel = "实时服务 配准灰度人脸";
    else
        [img, sourceLabel] = current_preprocess_base_image(state);
        if isempty(img)
            set_pre_status(handles, '状态：请先输入图像。');
            return;
        end
        grayImg = convert_to_gray(img);
    end

    state.currentGrayImage = grayImg;
    state.currentProcessedImage = grayImg;
    state.currentPreprocessBaseImage = grayImg;
    state.currentPreprocessBaseLabel = sourceLabel;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, grayImg, char(sourceLabel));
    refresh_image_info(handles, grayImg, "已对" + sourceLabel + "完成灰度变换。");
end

function on_equalize_image(handles)
    state = get_state(handles);
    if is_service_preprocess_state(state) && isfield(state, 'serviceEqualizedFace') && ~isempty(state.serviceEqualizedFace)
        eqImg = state.serviceEqualizedFace;
        sourceLabel = "实时服务 CLAHE 均衡化人脸";
    else
        [img, sourceLabel] = current_preprocess_base_image(state);
        if isempty(img)
            set_pre_status(handles, '状态：请先输入图像。');
            return;
        end
        eqImg = equalize_image(img);
    end

    state.currentGrayImage = eqImg;
    state.currentProcessedImage = eqImg;
    state.currentPreprocessBaseImage = eqImg;
    state.currentPreprocessBaseLabel = sourceLabel;
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, eqImg, char(sourceLabel));
    refresh_image_info(handles, eqImg, "已对" + sourceLabel + "完成直方图均衡化。");
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

    sourceLabel = current_source_label(state);
    fig = uifigure('Name', '灰度直方图', 'Position', [180 120 640 420]);
    ax = uiaxes(fig, 'Position', [30 40 580 340]);
    draw_histogram(img, ax);
    title(ax, ['灰度直方图 - ', char(sourceLabel)]);
    set_pre_status(handles, "状态：灰度直方图已绘制；统计对象：" + sourceLabel + "；横轴=灰度值0到255，纵轴=该灰度值的像素数量。");
end

function on_translate_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    try
        offsetText = handles.Preprocess.TranslateEdit.Value;
        outImg = translate_image(img, offsetText);
    catch ME
        set_pre_status(handles, "状态：图像平移失败: " + string(ME.message));
        return;
    end

    state.currentProcessedImage = outImg;
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = "平移后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, '图像平移');
    refresh_image_info(handles, outImg, "已完成图像平移，参数 " + string(handles.Preprocess.TranslateEdit.Value) + "。");
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
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = "缩放后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('缩放 %.2fx', factor));
    refresh_image_info(handles, outImg, sprintf('已完成图像缩放 %.2fx。', factor));
end

function on_shear_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    shearValue = str2double(handles.Preprocess.ShearEdit.Value);
    if isempty(img) || isnan(shearValue)
        set_pre_status(handles, '状态：请先输入图像，并填写切变系数，例如 0.2。');
        return;
    end

    try
        outImg = shear_image(img, shearValue);
    catch ME
        set_pre_status(handles, "状态：图像切变失败: " + string(ME.message));
        return;
    end

    state.currentProcessedImage = outImg;
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = "切变后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('切变 %.2f', shearValue));
    refresh_image_info(handles, outImg, sprintf('已完成图像切变 %.2f。', shearValue));
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
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = "旋转后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('旋转 %.1f°', angle));
    refresh_image_info(handles, outImg, sprintf('已完成图像旋转 %.1f 度。', angle));
end

function on_brightness_image(handles)
    state = get_state(handles);
    img = current_source_image(state);
    delta = str2double(handles.Preprocess.BrightnessEdit.Value);
    if isempty(img) || isnan(delta)
        set_pre_status(handles, '状态：请先输入图像，并填写亮度增量，例如 30 或 -30。');
        return;
    end

    try
        outImg = adjust_brightness(img, delta);
    catch ME
        set_pre_status(handles, "状态：亮度调整失败: " + string(ME.message));
        return;
    end

    state.currentProcessedImage = outImg;
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = "亮度调整后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, sprintf('亮度 %+g', delta));
    refresh_image_info(handles, outImg, sprintf('已完成亮度调整 %+g。', delta));
end

function on_restore_original_image(handles)
    state = get_state(handles);
    img = get_optional_field(state, 'currentRestoreImage', []);
    label = get_optional_field(state, 'currentRestoreLabel', "原图");
    if isempty(img)
        [img, label] = current_preprocess_base_image(state);
    end
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像、启动摄像头或框选人脸。');
        return;
    end

    state.currentGrayImage = [];
    state.currentProcessedImage = img;
    state.currentPreprocessBaseImage = img;
    state.currentPreprocessBaseLabel = label;
    set_state(handles, state);

    update_axes_image(handles.Preprocess.ProcessedAxes, img, '恢复原图');
    refresh_image_info(handles, img, "已恢复到" + string(label) + "。");
end

function on_flip_image(handles, mode)
    state = get_state(handles);
    img = current_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像。');
        return;
    end

    if strcmpi(string(mode), "horizontal")
        mode = 'horizontal';
        modeText = '水平';
    else
        mode = 'vertical';
        modeText = '垂直';
    end

    try
        outImg = flip_image(img, mode);
    catch ME
        set_pre_status(handles, "状态：图像翻转失败: " + string(ME.message));
        return;
    end

    state.currentProcessedImage = outImg;
    state.currentPreprocessBaseImage = outImg;
    state.currentPreprocessBaseLabel = string(modeText) + "翻转后的图像";
    set_state(handles, state);
    update_axes_image(handles.Preprocess.ProcessedAxes, outImg, ['图像', modeText, '翻转']);
    refresh_image_info(handles, outImg, ['已完成图像', modeText, '翻转。']);
end

function on_start_camera(handles)
    state = get_state(handles);
    state = stop_embedded_realtime(state);
    state = clear_service_preprocess_mode(state);
    state.cameraTimer = stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
    state = stop_manual_face_roi(state);
    state.currentFaceInfo = struct();
    state.currentFaceBox = [];

    [cam, message] = camera_start();
    if isempty(cam)
        state.camera = [];
        set_state(handles, state);
        set_pre_status(handles, "状态：" + message);
        return;
    end

    [frame, snapMessage] = camera_snapshot(cam);
    state.camera = cam;
    if ~isempty(frame)
        state.currentCameraFrame = frame;
        state.currentImage = frame;
        state.currentImagePath = "camera";
        state.currentPreprocessBaseImage = frame;
        state.currentPreprocessBaseLabel = "左侧摄像头当前帧";
        state.currentRestoreImage = frame;
        state.currentRestoreLabel = "左侧摄像头当前帧";
        state.currentGrayImage = [];
        state.currentProcessedImage = [];
        update_axes_image(handles.Preprocess.InputAxes, frame, '拍摄 / 输入原图');
        initialize_empty_axes(handles.Preprocess.ProcessedAxes, '处理后图像');
        refresh_image_info(handles, frame, snapMessage + " 摄像头实时预览已启动。");
    else
        set_pre_status(handles, "状态：" + message + " " + snapMessage);
    end

    previewTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'Period', 0.15, ...
        'BusyMode', 'drop', ...
        'Name', 'PCAFacePreprocessCameraPreview', ...
        'TimerFcn', @(~, ~) on_camera_timer_tick(handles));
    state.cameraTimer = previewTimer;
    set_state(handles, state);

    try
        start(previewTimer);
    catch ME
        state = get_state(handles);
        state.cameraTimer = stop_camera_timer(previewTimer);
        set_state(handles, state);
        set_pre_status(handles, "状态：摄像头已打开，但实时预览启动失败: " + string(ME.message));
    end
end

function on_stop_camera(handles)
    state = get_state(handles);
    state.cameraTimer = stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
    message = camera_stop(get_optional_field(state, 'camera', []));
    state.camera = [];
    set_state(handles, state);
    set_pre_status(handles, "状态：" + message);
end

function on_manual_select_face(handles)
    state = get_state(handles);
    state.cameraTimer = stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
    state = clear_service_preprocess_mode(state);
    state = stop_manual_face_roi(state);
    set_state(handles, state);

    img = original_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像或启动摄像头。');
        return;
    end

    update_axes_image(handles.Preprocess.InputAxes, img, '拖动框选人脸，双击确认');
    set_pre_status(handles, '状态：请在左侧原图上拖动/缩放框选人脸，右侧会实时刷新，双击矩形确认。');

    faceInfo = manual_select_face(img, handles.Preprocess.InputAxes, ...
        @(updatedFaceInfo) update_manual_face_preview(handles, updatedFaceInfo));

    state = get_state(handles);
    state.currentFaceInfo = faceInfo;
    state.currentFaceBox = faceInfo.faceBox;
    state.currentFaceRoi = get_optional_field(faceInfo, 'roi', []);
    state.currentFaceRoiListeners = get_optional_field(faceInfo, 'roiListeners', []);
    if isfield(faceInfo, 'faceImage') && ~isempty(faceInfo.faceImage)
        state.currentProcessedImage = faceInfo.faceImage;
        state.currentPreprocessBaseImage = faceInfo.faceImage;
        state.currentPreprocessBaseLabel = "手动框选人脸";
        state.currentRestoreImage = faceInfo.faceImage;
        state.currentRestoreLabel = "手动框选人脸";
        update_axes_image(handles.Preprocess.ProcessedAxes, faceInfo.faceImage, '手动框选人脸');
        refresh_image_info(handles, faceInfo.faceImage, faceInfo.message);
    else
        set_pre_status(handles, "状态：" + string(faceInfo.message));
    end
    set_state(handles, state);
end

function update_manual_face_preview(handles, faceInfo)
    if isempty(handles) || ~isfield(handles, 'Figure') || ~isvalid(handles.Figure)
        return;
    end
    if ~isfield(faceInfo, 'faceImage') || isempty(faceInfo.faceImage)
        return;
    end

    state = get_state(handles);
    state.currentFaceInfo = faceInfo;
    state.currentFaceBox = faceInfo.faceBox;
    state.currentFaceRoi = get_optional_field(faceInfo, 'roi', []);
    state.currentFaceRoiListeners = get_optional_field(faceInfo, 'roiListeners', []);
    state.currentProcessedImage = faceInfo.faceImage;
    state.currentPreprocessBaseImage = faceInfo.faceImage;
    state.currentPreprocessBaseLabel = "手动框选人脸";
    state.currentRestoreImage = faceInfo.faceImage;
    state.currentRestoreLabel = "手动框选人脸";
    set_state(handles, state);

    update_axes_image(handles.Preprocess.ProcessedAxes, faceInfo.faceImage, '手动框选人脸');
    set_pre_status(handles, "状态：" + string(faceInfo.message));
    drawnow limitrate nocallbacks;
end

function on_camera_timer_tick(handles)
    if isempty(handles) || ~isfield(handles, 'Figure') || ~isvalid(handles.Figure)
        return;
    end

    state = get_state(handles);
    cam = get_optional_field(state, 'camera', []);
    if isempty(cam)
        state.cameraTimer = stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
        set_state(handles, state);
        return;
    end

    [frame, message] = camera_snapshot(cam);
    if isempty(frame)
        set_pre_status(handles, "状态：" + message);
        return;
    end

    state.currentCameraFrame = frame;
    state.currentImage = frame;
    state.currentImagePath = "camera_live";
    if ~isfield(state, 'currentFaceInfo') || isempty(fieldnames(state.currentFaceInfo))
        state.currentPreprocessBaseImage = frame;
        state.currentPreprocessBaseLabel = "左侧摄像头当前帧";
        state.currentRestoreImage = frame;
        state.currentRestoreLabel = "左侧摄像头当前帧";
    end
    set_state(handles, state);
    update_axes_image(handles.Preprocess.InputAxes, frame, '摄像头实时画面');
    drawnow limitrate nocallbacks;
end

function timerObj = stop_camera_timer(timerObj)
    if nargin < 1 || isempty(timerObj)
        timerObj = [];
        return;
    end

    try
        if isvalid(timerObj)
            stop(timerObj);
            delete(timerObj);
        end
    catch
    end
    timerObj = [];
end

function on_close_figure(handles, fig)
    try
        state = get_state(handles);
        stop_manual_face_roi(state);
        stop_embedded_realtime(state);
        stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
        camera_stop(get_optional_field(state, 'camera', []));
    catch
    end
    delete(fig);
end

function state = stop_manual_face_roi(state)
    listeners = get_optional_field(state, 'currentFaceRoiListeners', []);
    roi = get_optional_field(state, 'currentFaceRoi', []);

    try
        if ~isempty(listeners)
            delete(listeners);
        end
    catch
    end

    try
        if ~isempty(roi) && isvalid(roi)
            delete(roi);
        end
    catch
    end

    state.currentFaceRoi = [];
    state.currentFaceRoiListeners = [];
end

function on_detect_face(handles)
    state = get_state(handles);
    img = original_source_image(state);
    if isempty(img)
        set_pre_status(handles, '状态：请先输入图像或启动摄像头。');
        return;
    end

    storedFaceInfo = get_optional_field(state, 'currentFaceInfo', struct());
    if isstruct(storedFaceInfo) && isfield(storedFaceInfo, 'status') && ...
            string(storedFaceInfo.status) == "ok" && isfield(storedFaceInfo, 'faceImage') && ...
            ~isempty(storedFaceInfo.faceImage)
        faceInfo = storedFaceInfo;
        if is_service_preprocess_state(state)
            faceInfo.message = "已显示 实时服务 MediaPipe 人脸检测框。";
        else
            faceInfo.message = "已显示实时采集保存的人脸检测框。";
        end
    else
        state = clear_service_preprocess_mode(state);
        faceInfo = detect_face(img, struct());
    end
    state.currentFaceInfo = faceInfo;
    state.currentFaceBox = faceInfo.faceBox;
    if isfield(faceInfo, 'faceImage') && ~isempty(faceInfo.faceImage)
        state.currentProcessedImage = faceInfo.faceImage;
        state.currentPreprocessBaseImage = faceInfo.faceImage;
        if is_service_preprocess_state(state)
            state.currentPreprocessBaseLabel = "实时服务 检测到的人脸";
        else
            state.currentPreprocessBaseLabel = "检测到的人脸";
        end
        state.currentRestoreImage = faceInfo.faceImage;
        state.currentRestoreLabel = state.currentPreprocessBaseLabel;
        update_axes_image(handles.Preprocess.ProcessedAxes, faceInfo.faceImage, char(state.currentPreprocessBaseLabel));
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
        set_pre_status(handles, '状态：请先点击“人脸检测”或“人脸框选”，得到可校准的人脸。');
        return;
    end

    if is_service_preprocess_state(state) && isfield(state, 'serviceAlignedFace') && ~isempty(state.serviceAlignedFace)
        alignInfo = get_optional_field(state, 'currentAlignInfo', struct());
        alignInfo.status = "ok";
        alignInfo.alignedFace = state.serviceAlignedFace;
        alignInfo.message = "实时服务 眼-眼-嘴仿射配准 + CLAHE + 软遮罩";
        alignInfo.transformInfo = struct('method', "runtime_service_mediapipe_3point_tight_masked");
    else
        options = struct('imageSize', [112, 92]);
        alignInfo = align_face(img, faceInfo, options);
    end
    state.currentAlignInfo = alignInfo;
    if isfield(alignInfo, 'alignedFace') && ~isempty(alignInfo.alignedFace)
        state.currentAlignedFace = alignInfo.alignedFace;
        state.currentProcessedImage = alignInfo.alignedFace;
        state.currentPreprocessBaseImage = alignInfo.alignedFace;
        if is_service_preprocess_state(state)
            state.currentPreprocessBaseLabel = "实时服务 配准后人脸";
        else
            state.currentPreprocessBaseLabel = "校准后人脸";
        end
        state.currentRestoreImage = alignInfo.alignedFace;
        state.currentRestoreLabel = state.currentPreprocessBaseLabel;
        update_axes_image(handles.Preprocess.ProcessedAxes, alignInfo.alignedFace, char(state.currentPreprocessBaseLabel));
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

function on_try_realtime_recognition(handles)
    state = get_state(handles);
    existingTimer = get_optional_field(state, 'realtimeBridgeTimer', []);
    if ~isempty(existingTimer) && isvalid(existingTimer) && strcmp(existingTimer.Running, 'on')
        state = stop_embedded_realtime(state);
        set_state(handles, state);
        set_rec_status(handles, '状态：实时识别已停止。');
        append_status_log(handles, '实时识别：已停止。');
        return;
    end

    try
        state.cameraTimer = stop_camera_timer(get_optional_field(state, 'cameraTimer', []));
        camera_stop(get_optional_field(state, 'camera', []));
        state.camera = [];

        params = struct();
        params.pcaDim = handles.Recognition.PcaDimEdit.Value;
        params.svmC = handles.Recognition.SvmCEdit.Value;
        state.model = ensure_recognition_model(state, params);
        state.realtimeBridge = start_realtime_camera_service(state.rootDir);
        state.realtimeLastSequence = -1;
        state.realtimeFps = 0;
        state.realtimeLastTic = tic;

        realtimeTimer = timer( ...
            'ExecutionMode', 'fixedSpacing', ...
            'Period', 0.10, ...
            'BusyMode', 'drop', ...
            'Name', 'PCAFaceEmbeddedRealtimeService', ...
            'TimerFcn', @(~, ~) on_embedded_realtime_tick(handles));
        state.realtimeBridgeTimer = realtimeTimer;
        set_state(handles, state);

        start(realtimeTimer);
        set_rec_status(handles, '状态：实时识别已启动；再次点击“实时识别”可停止。');
        append_status_log(handles, '实时识别：已在当前 GUI 中启动。');
        drawnow;
    catch ME
        state = stop_embedded_realtime(get_state(handles));
        set_state(handles, state);
        message = "实时识别启动失败: " + string(ME.message);
        set_rec_status(handles, "状态：" + message);
        append_status_log(handles, message);
    end
end

function on_embedded_realtime_tick(handles)
    if isempty(handles) || ~isfield(handles, 'Figure') || ~isvalid(handles.Figure)
        return;
    end

    state = get_state(handles);
    bridge = get_optional_field(state, 'realtimeBridge', struct());
    lastSequence = get_optional_field(state, 'realtimeLastSequence', -1);
    packet = read_realtime_camera_service_frame(bridge, lastSequence);

    if any(strcmp(packet.status, {'startup_error', 'stopped'}))
        state = stop_embedded_realtime(state);
        set_state(handles, state);
        set_rec_status(handles, "状态：实时识别已停止：" + string(packet.message));
        append_status_log(handles, "实时识别停止：" + string(packet.message));
        return;
    end

    if ~packet.hasNewFrame
        return;
    end

    model = get_optional_field(state, 'model', struct());
    pred = predict_face_identity(model, packet.alignedFace, struct('topK', 3));

    elapsed = toc(get_optional_field(state, 'realtimeLastTic', tic));
    fps = get_optional_field(state, 'realtimeFps', 0);
    if elapsed > 0
        fps = 0.85 * fps + 0.15 * (1 / elapsed);
    end

    state.realtimeLastSequence = packet.sequence;
    state.realtimeLastTic = tic;
    state.realtimeFps = fps;
    state.currentCameraFrame = packet.rawFrame;
    state.currentFaceBox = get_optional_field(packet.meta, 'faceBox', []);
    state.currentAlignedFace = packet.alignedFace;
    state.realtimeResult = pred;
    state.lastReplayPackage = build_realtime_replay_package(packet);
    set_state(handles, state);

    if ~isempty(packet.rawFrame)
        update_axes_image(handles.Recognition.SourceAxes, packet.rawFrame, sprintf('输入 / 摄像头 | %.1f FPS', fps));
        draw_face_box(handles.Recognition.SourceAxes, get_optional_field(packet.meta, 'faceBox', []));
    end
    update_axes_image(handles.Recognition.FaceAxes, packet.alignedFace, ...
        sprintf('识别人脸 | %s', char(get_optional_field(packet.meta, 'status', 'runtime_service'))));
    handles.Recognition.SingleResultText.Value = build_realtime_result_text(pred, packet, fps);
    update_realtime_records_table(handles, pred, packet, fps);

    topText = format_prediction_topk(pred);
    set_rec_status(handles, sprintf('状态：实时识别 #%d | %.1f FPS | %s', packet.sequence, fps, topText));
    drawnow limitrate nocallbacks;
end

function state = stop_embedded_realtime(state)
    state.realtimeBridgeTimer = stop_camera_timer(get_optional_field(state, 'realtimeBridgeTimer', []));
    stop_realtime_camera_service(get_optional_field(state, 'realtimeBridge', struct()));
    state.realtimeBridge = struct();
    state.realtimeLastSequence = -1;
    state.realtimeFps = 0;
    state.realtimeLastTic = [];
end

function draw_face_box(ax, faceBox)
    if isempty(ax) || ~isvalid(ax) || isempty(faceBox) || numel(faceBox) ~= 4
        return;
    end

    hold(ax, 'on');
    rectangle(ax, 'Position', double(faceBox(:))', 'EdgeColor', 'g', 'LineWidth', 2);
    hold(ax, 'off');
end

function textLines = build_realtime_result_text(pred, packet, fps)
    topText = format_prediction_topk(pred);
    elapsedMs = get_optional_field(pred, 'elapsedMs', []);
    if isempty(elapsedMs)
        predTime = '-';
    else
        predTime = sprintf('%.2f ms', elapsedMs);
    end

    alignMs = get_optional_field(packet.meta, 'processMs', []);
    if isempty(alignMs)
        alignTime = '-';
    else
        alignTime = sprintf('%.2f ms', alignMs);
    end

    textLines = {
        char("实时预测: " + string(get_optional_field(pred, 'name', "-")))
        char("Top-3: " + string(topText))
        sprintf('摄像头帧: #%d | %.1f FPS', packet.sequence, fps)
        ['配准耗时: ', alignTime]
        ['PCA/SVM耗时: ', predTime]
    };
end

function text = format_prediction_topk(pred)
    names = get_optional_field(pred, 'topKNames', {});
    scores = get_optional_field(pred, 'topKScores', []);
    if isempty(names)
        text = 'no prediction';
        return;
    end

    topCount = min(3, numel(names));
    parts = strings(1, topCount);
    for i = 1:topCount
        if ~isempty(scores) && numel(scores) >= i
            parts(i) = string(names{i}) + sprintf('(%.4f)', scores(i));
        else
            parts(i) = string(names{i});
        end
    end
    text = char(strjoin(parts, ' | '));
end

function update_realtime_records_table(handles, pred, packet, fps)
    if ~isfield(handles.Recognition, 'RealtimeRecordsTable') || isempty(handles.Recognition.RealtimeRecordsTable)
        return;
    end

    oldData = handles.Recognition.RealtimeRecordsTable.Data;
    if isempty(oldData)
        oldData = cell(10, 4);
    end
    newRow = {
        packet.sequence, ...
        sprintf('%.1f FPS', fps), ...
        get_optional_field(pred, 'name', ''), ...
        char(get_optional_field(packet.meta, 'status', 'runtime_service'))
    };
    handles.Recognition.RealtimeRecordsTable.Data = [newRow; oldData(1:max(0, min(size(oldData, 1), 9)), :)];
end

function replayPkg = build_realtime_replay_package(packet)
    rawFrame = get_optional_field(packet, 'rawFrame', []);
    alignedFace = get_optional_field(packet, 'alignedFace', []);
    faceCrop = get_optional_field(packet, 'faceCrop', []);
    grayFace = get_optional_field(packet, 'grayFace', []);
    equalizedFace = get_optional_field(packet, 'equalizedFace', []);
    alignedColor = get_optional_field(packet, 'alignedColor', []);
    meta = get_optional_field(packet, 'meta', struct());
    faceBox = get_optional_field(meta, 'faceBox', []);
    faceImage = faceCrop;
    if isempty(faceImage)
        faceImage = crop_face_from_box(rawFrame, faceBox);
    end
    if isempty(faceImage)
        faceImage = alignedFace;
    end

    replayPkg = struct();
    replayPkg.rawFrame = rawFrame;
    replayPkg.faceBox = faceBox;
    replayPkg.faceImage = faceImage;
    replayPkg.faceColorImage = faceImage;
    replayPkg.serviceAlignedColor = alignedColor;
    replayPkg.serviceGrayFace = grayFace;
    replayPkg.serviceEqualizedFace = equalizedFace;
    replayPkg.serviceAlignedFace = alignedFace;
    replayPkg.alignedFace = alignedFace;
    replayPkg.landmarks = struct();
    replayPkg.preprocessMode = "runtime_service";
    replayPkg.timestamp = datetime('now');
    replayPkg.message = char(get_optional_field(meta, 'status', 'runtime_service'));
end

function faceImage = crop_face_from_box(img, box)
    faceImage = [];
    if isempty(img) || isempty(box) || numel(box) ~= 4
        return;
    end

    h = size(img, 1);
    w = size(img, 2);
    x = max(1, min(w, round(box(1))));
    y = max(1, min(h, round(box(2))));
    bw = max(1, round(box(3)));
    bh = max(1, round(box(4)));
    bw = min(bw, w - x + 1);
    bh = min(bh, h - y + 1);
    faceImage = img(y:y + bh - 1, x:x + bw - 1, :);
end

function on_train_model(handles)
    state = get_state(handles);
    pcaDim = handles.Recognition.PcaDimEdit.Value;
    svmC = handles.Recognition.SvmCEdit.Value;
    params = struct('pcaDim', pcaDim, 'svmC', svmC, 'forceTrain', true);

    try
        model = ensure_recognition_model(state, params);
        trainDir = get_optional_field(model, 'trainDir', get_optional_field(state, 'defaultTrainDir', ""));
        state.model = model;
        set_state(handles, state);
        update_param_text(handles, model, trainDir, pcaDim, svmC);

        status = string(get_optional_field(model, 'status', "ok"));
        message = string(get_optional_field(model, 'message', "模型训练完成。"));
        if status == "todo"
            message = "B 同学训练接口未完成：" + message;
        end
        set_rec_status(handles, "状态：" + message);
        append_status_log(handles, "重新训练模型：" + message);
    catch ME
        set_rec_status(handles, "状态：模型训练失败: " + string(ME.message));
        append_status_log(handles, "模型训练失败: " + string(ME.message));
    end
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
    if string(actionName) == "查看预处理过程" && ...
            isfield(result, 'rawFrame') && ~isempty(result.rawFrame)
        handles.TabGroup.SelectedTab = handles.Preprocess.Parent;
        update_axes_image(handles.Preprocess.InputAxes, result.rawFrame, '拍摄 / 输入原图');
        if isfield(result, 'faceBox') && ~isempty(result.faceBox)
            draw_face_box(handles.Preprocess.InputAxes, result.faceBox);
        end
        if isfield(result, 'alignedFace') && ~isempty(result.alignedFace)
            update_axes_image(handles.Preprocess.ProcessedAxes, result.alignedFace, '配准后人脸');
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

    state = get_state(handles);
    if isfield(state, 'model') && isstruct(state.model) && ~isempty(state.model)
        pcaDim = handles.Recognition.PcaDimEdit.Value;
        svmC = handles.Recognition.SvmCEdit.Value;
        trainDir = get_optional_field(state.model, 'trainDir', get_optional_field(state, 'defaultTrainDir', ""));
        update_param_text(handles, state.model, trainDir, pcaDim, svmC);
    end
end

function update_param_text(handles, model, trainDir, pcaDim, svmC)
    status = string(get_optional_field(model, 'status', "ok"));
    message = string(get_optional_field(model, 'message', ""));
    actualPcaDim = get_optional_field(model, 'pcaDim', pcaDim);
    actualSvmC = get_optional_field(model, 'svmC', svmC);
    svmParams = get_optional_field(model, 'svmParams', struct());
    if isstruct(svmParams) && isfield(svmParams, 'C') && ~isempty(svmParams.C)
        actualSvmC = svmParams.C;
    end
    imageSize = get_optional_field(model, 'imageSize', []);
    if isempty(imageSize)
        sizeText = "112x92";
    elseif numel(imageSize) >= 2
        sizeText = sprintf('%dx%d', imageSize(1), imageSize(2));
    else
        sizeText = string(imageSize);
    end

    labels = get_optional_field(model, 'labels', {});
    if isempty(labels)
        labelCount = 0;
    else
        labelCount = numel(labels);
    end

    handles.Recognition.ParamText.Value = {
        char("PCA 维数: " + string(actualPcaDim))
        char("SVM C: " + string(actualSvmC))
        char("模型状态: " + status)
        char("训练目录: " + string(trainDir))
        char("训练类别数: " + string(labelCount))
        char("输入尺寸: " + string(sizeText))
        char("接口信息: " + message)
    };
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

function [img, label] = current_preprocess_base_image(state)
    if isfield(state, 'currentPreprocessBaseImage') && ~isempty(state.currentPreprocessBaseImage)
        img = state.currentPreprocessBaseImage;
        label = get_optional_field(state, 'currentPreprocessBaseLabel', "当前预处理基准图");
        if strlength(string(label)) == 0
            label = "当前预处理基准图";
        end
        return;
    end

    faceInfo = get_optional_field(state, 'currentFaceInfo', struct());
    if isstruct(faceInfo) && isfield(faceInfo, 'faceImage') && ~isempty(faceInfo.faceImage)
        img = faceInfo.faceImage;
        label = "手动框选人脸";
        return;
    end

    img = current_source_image(state);
    label = current_source_label(state);
end

function label = current_source_label(state)
    if isfield(state, 'currentProcessedImage') && ~isempty(state.currentProcessedImage)
        label = "右侧处理后图像";
    elseif isfield(state, 'currentGrayImage') && ~isempty(state.currentGrayImage)
        label = "当前灰度图像";
    elseif isfield(state, 'currentCameraFrame') && ~isempty(state.currentCameraFrame)
        label = "左侧摄像头当前帧";
    elseif isfield(state, 'currentImage') && ~isempty(state.currentImage)
        label = "左侧输入原图";
    else
        label = "无图像";
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

function tf = is_service_preprocess_state(state)
    tf = isstruct(state) && isfield(state, 'preprocessMode') && ...
        strcmp(string(state.preprocessMode), "runtime_service");
end

function state = clear_service_preprocess_mode(state)
    state.preprocessMode = "";
    state.serviceFaceImage = [];
    state.serviceGrayFace = [];
    state.serviceEqualizedFace = [];
    state.serviceAlignedFace = [];
    state.serviceAlignedColor = [];
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
