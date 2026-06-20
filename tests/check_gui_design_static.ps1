$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot

function Assert-FileContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $fullPath = Join-Path $repo $Path
    if (-not (Test-Path $fullPath)) {
        throw "Missing file: $Path"
    }

    $content = Get-Content -Raw -LiteralPath $fullPath
    if ($content -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-FileNotContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Message
    )

    $fullPath = Join-Path $repo $Path
    if (-not (Test-Path $fullPath)) {
        throw "Missing file: $Path"
    }

    $content = Get-Content -Raw -LiteralPath $fullPath
    if ($content -match $Pattern) {
        throw $Message
    }
}

Assert-FileContains 'config\get_ui_theme.m' 'function\s+theme\s*=\s*get_ui_theme' 'Theme function is missing.'
Assert-FileContains 'ui\apply_cute_button_style.m' 'function\s+apply_cute_button_style' 'Button style helper is missing.'
Assert-FileContains 'ui\load_ui_assets.m' 'function\s+assets\s*=\s*load_ui_assets' 'Asset loader is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'uigridlayout\(.*\[1\s+3\]' 'Preprocess tab must use a 1x3 grid layout.'
Assert-FileContains 'ui\create_recognition_tab.m' 'uigridlayout\(.*\[1\s+3\]' 'Recognition tab must use a 1x3 grid layout.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'Main Function Block' 'Preprocess left title is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'Image Display Area' 'Preprocess center title is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'ImgProcessing Toolbox' 'Preprocess right title is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'Recognition Control Block' 'Recognition left title is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'Recognition Display Area' 'Recognition center title is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'Result & Parameter Block' 'Recognition right title is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'theme\.colors\.mintGreen' 'Recognition left panel should use the green preprocess style.'
Assert-FileContains 'ui\create_recognition_tab.m' 'theme\.colors\.paleSkyBlue' 'Recognition right panel should use the blue preprocess style.'
Assert-FileContains 'ui\create_recognition_tab.m' 'RealtimeRecordsTable' 'Realtime records table handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'Mascot' 'Preprocess mascot decoration handle is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'Mascot' 'Recognition mascot decoration handle is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'assets\.leftCorner' 'Recognition left mascot should match preprocess left image.'
Assert-FileContains 'ui\create_recognition_tab.m' 'assets\.rightCornerBlue' 'Recognition right mascot should match preprocess blue image.'
Assert-FileNotContains 'ui\create_recognition_tab.m' 'innovation compare block' 'Recognition innovation block should be removed.'
Assert-FileNotContains 'ui\create_recognition_tab.m' 'CompareModeDropDown' 'Recognition innovation dropdown should be removed.'
Assert-FileNotContains 'ui\create_recognition_tab.m' 'PreprocessCompareButton' 'Recognition innovation button should be removed.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'PreprocessCompareButton' 'Removed innovation button must not be bound.'
Assert-FileContains 'ui\load_ui_assets.m' 'leftCorner' 'Left corner decoration asset is missing.'
Assert-FileContains 'ui\load_ui_assets.m' 'rightCornerBlue' 'Right blue corner decoration asset is missing.'
Assert-FileContains 'ui\initialize_empty_axes.m' 'function\s+initialize_empty_axes' 'Empty axes helper is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'initialize_empty_axes' 'Preprocess tab must keep image display axes empty.'
Assert-FileContains 'ui\create_recognition_tab.m' 'initialize_empty_axes' 'Recognition tab must keep image display axes empty.'
Assert-FileContains 'ui\bind_callbacks.m' 'ImportButton\.ButtonPushedFcn' 'Import image callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'GrayButton\.ButtonPushedFcn' 'Gray conversion callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'function\s+on_gray_image[\s\S]*?current_preprocess_base_image' 'Gray conversion must use the current preprocess base image.'
Assert-FileContains 'ui\bind_callbacks.m' 'EqualizeButton\.ButtonPushedFcn' 'Equalization callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'function\s+on_equalize_image[\s\S]*?current_preprocess_base_image' 'Equalization must use the current preprocess base image.'
Assert-FileContains 'ui\bind_callbacks.m' 'currentPreprocessBaseImage' 'Preprocess base image must be tracked in app state.'
Assert-FileContains 'ui\bind_callbacks.m' 'StatsButton\.ButtonPushedFcn' 'Image stats callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'BatchTestButton\.ButtonPushedFcn' 'Batch test callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'TrainButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_train_model' 'Train button must call a real training handler.'
Assert-FileContains 'ui\bind_callbacks.m' 'RealtimePredictButton\.ButtonPushedFcn' 'Realtime recognition callback is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'InputAxes' 'Original/captured image axes handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'ProcessedAxes' 'Processed image axes handle is missing.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'ExternalFigureDropDown' 'External figure selector should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'DisplayModeDropDown' 'Image display selector should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' '图像显示选择' 'Image display selector label should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'BrightenButton' 'Brighten special-effect button should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'StickerButton' 'Sticker special-effect button should be removed.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'BrightenButton' 'Removed brighten button must not be bound.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'StickerButton' 'Removed sticker button must not be bound.'
Assert-FileContains 'preprocess\camera_start.m' 'webcam' 'camera_start must attempt to use MATLAB webcam.'
Assert-FileContains 'preprocess\camera_snapshot.m' 'snapshot' 'camera_snapshot must capture a frame.'
Assert-FileContains 'preprocess\detect_face.m' 'CascadeObjectDetector' 'detect_face must use CascadeObjectDetector when available.'
Assert-FileContains 'preprocess\align_face.m' 'imresize' 'align_face must resize aligned faces.'
Assert-FileContains 'preprocess\translate_image.m' 'function\s+outImg\s*=\s*translate_image' 'translate_image helper is missing.'
Assert-FileContains 'preprocess\shear_image.m' 'function\s+outImg\s*=\s*shear_image' 'shear_image helper is missing.'
Assert-FileContains 'preprocess\adjust_brightness.m' 'function\s+outImg\s*=\s*adjust_brightness' 'adjust_brightness helper is missing.'
Assert-FileContains 'preprocess\flip_image.m' 'function\s+outImg\s*=\s*flip_image' 'flip_image helper is missing.'
Assert-FileContains 'preprocess\manual_select_face.m' 'function\s+faceInfo\s*=\s*manual_select_face' 'manual_select_face helper is missing.'
Assert-FileNotContains 'preprocess\manual_select_face.m' 'position\s*=\s*wait\s*\(' 'manual_select_face must not request an output from wait(roi).'
Assert-FileContains 'preprocess\manual_select_face.m' 'roi\.Position' 'manual_select_face must read the selected rectangle from roi.Position.'
Assert-FileContains 'preprocess\manual_select_face.m' 'addlistener\(roi,\s*''ROIMoved''' 'manual_select_face must refresh the crop after resizing the ROI.'
Assert-FileContains 'preprocess\manual_select_face.m' 'addlistener\(roi,\s*''MovingROI''' 'manual_select_face must refresh the crop while dragging the ROI.'
Assert-FileContains 'ui\bind_callbacks.m' 'update_manual_face_preview' 'Manual face ROI updates must refresh the processed preview.'
Assert-FileContains 'ui\bind_callbacks.m' 'currentFaceRoi' 'Manual face ROI handle must be stored in app state.'
Assert-FileContains 'ui\bind_callbacks.m' 'currentFaceRoiListeners' 'Manual face ROI listeners must be stored in app state.'
Assert-FileContains 'preprocess\draw_histogram.m' 'xlabel' 'Histogram must label the grayscale-value x axis.'
Assert-FileContains 'preprocess\draw_histogram.m' 'ylabel' 'Histogram must label the pixel-count y axis.'
Assert-FileContains 'ui\bind_callbacks.m' 'current_source_label' 'Histogram status must describe which image is being measured.'
Assert-FileNotContains 'preprocess\detect_face.m' 'detect_face not implemented' 'detect_face placeholder message must be removed.'
Assert-FileNotContains 'preprocess\align_face.m' 'align_face not implemented' 'align_face placeholder message must be removed.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_start_camera' 'Start camera button must call real camera flow.'
Assert-FileContains 'ui\bind_callbacks.m' 'cameraTimer' 'Camera preview timer must be tracked in app state.'
Assert-FileContains 'ui\bind_callbacks.m' 'timer\(' 'Start camera must create a live preview timer.'
Assert-FileContains 'ui\bind_callbacks.m' 'TimerFcn' 'Camera preview timer must refresh frames through TimerFcn.'
Assert-FileContains 'ui\bind_callbacks.m' 'stop_camera_timer' 'Stop camera must stop the live preview timer.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_manual_select_face' 'Face select button must call manual selection flow.'
Assert-FileContains 'ui\bind_callbacks.m' 'TranslateButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_translate_image' 'Translate button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'ShearButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_shear_image' 'Shear button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'BrightnessButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_brightness_image' 'Brightness button callback is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'HorizontalFlipButton' 'Horizontal flip button handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'VerticalFlipButton' 'Vertical flip button handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' '水平翻转' 'Horizontal flip button text is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' '垂直翻转' 'Vertical flip button text is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'HorizontalFlipButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_flip_image\(handles,\s*''horizontal''' 'Horizontal flip callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'VerticalFlipButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_flip_image\(handles,\s*''vertical''' 'Vertical flip callback is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'RestoreButton' 'Restore original button handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' '恢复原图' 'Restore original button text is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'RestoreButton\.ButtonPushedFcn\s*=\s*@\(~,\s*~\)\s*on_restore_original_image' 'Restore original callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'currentRestoreImage' 'Restore source image must be tracked in app state.'
Assert-FileContains 'ui\bind_callbacks.m' 'function\s+on_restore_original_image' 'Restore original handler is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_align_face' 'Face align button must call real alignment flow.'
Assert-FileContains 'integration\action_static_predict.m' 'predict_face_identity' 'Static prediction action must call predict_face_identity.'
Assert-FileContains 'integration\action_batch_predict.m' 'run_batch_test' 'Batch action must call run_batch_test.'
Assert-FileContains 'integration\action_realtime_predict.m' 'detect_face' 'Realtime action must detect faces.'
Assert-FileContains 'integration\action_realtime_predict.m' 'predict_face_identity' 'Realtime action must call predict_face_identity.'
Assert-FileContains 'config\app_config.m' 'rawFaceDir' 'App config must expose the raw face database directory.'
Assert-FileContains 'config\app_config.m' 'processedFaceDir' 'App config must expose the processed face image directory.'
Assert-FileContains 'config\app_config.m' 'final_result' 'App config must know the final_result location.'
Assert-FileContains 'config\app_config.m' '人脸识别' 'App config must know the 人脸识别 location.'
Assert-FileContains 'integration\action_static_predict.m' 'defaultTrainDir' 'Static prediction must use configured default training directory.'
Assert-FileContains 'integration\action_batch_predict.m' 'defaultTestDir' 'Batch prediction must use configured default test directory.'
Assert-FileContains 'integration\action_realtime_predict.m' 'defaultTrainDir' 'Realtime prediction must use configured default training directory.'

Write-Output 'GUI design static checks passed.'
