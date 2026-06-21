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
Assert-FileNotContains 'ui\create_recognition_tab.m' 'StopRealtimeButton' 'Recognition page should not keep a duplicate stop-camera/realtime button.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'PreprocessCompareButton' 'Removed innovation button must not be bound.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'StopRealtimeButton' 'Removed duplicate stop realtime button must not be bound.'
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
Assert-FileContains 'ui\bind_callbacks.m' 'TrainButton\.ButtonPushedFcn' 'Train button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_train_model' 'Train button must call a real training handler.'
Assert-FileContains 'ui\bind_callbacks.m' 'forceTrain' 'Train button must force real training instead of loading the committed v11 model.'
Assert-FileContains 'ui\bind_callbacks.m' 'RealtimePredictButton\.ButtonPushedFcn' 'Realtime recognition callback is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'RealtimePredictButton' 'Realtime button handle is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_try_realtime_recognition' 'Realtime button must use the 实时服务 launcher handler.'
Assert-FileContains 'ui\bind_callbacks.m' 'start_realtime_camera_service' 'Realtime handler must start the embedded 实时服务.'
Assert-FileContains 'ui\bind_callbacks.m' 'read_realtime_camera_service_frame' 'Realtime handler must poll bridge frames inside the existing GUI.'
Assert-FileContains 'ui\bind_callbacks.m' 'stop_realtime_camera_service' 'Realtime handler must stop the embedded 实时服务.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'run_realtime_runtime_service_gui' 'Realtime recognition must not open the old separate realtime window.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'InputAxes' 'Original/captured image axes handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'ProcessedAxes' 'Processed image axes handle is missing.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'ExternalFigureDropDown' 'External figure selector should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'DisplayModeDropDown' 'Image display selector should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'BrightenButton' 'Brighten special-effect button should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'StickerButton' 'Sticker special-effect button should be removed.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'BrightenButton' 'Removed brighten button must not be bound.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'StickerButton' 'Removed sticker button must not be bound.'
Assert-FileContains 'preprocess\camera_start.m' 'webcam' 'camera_start must attempt to use MATLAB webcam.'
Assert-FileContains 'preprocess\camera_snapshot.m' 'snapshot' 'camera_snapshot must capture a frame.'
Assert-FileContains 'preprocess\detect_face.m' 'CascadeObjectDetector' 'detect_face must use CascadeObjectDetector when available.'
Assert-FileContains 'preprocess\align_face.m' 'imwarp' 'align_face must warp aligned faces into the target size.'
Assert-FileContains 'preprocess\align_face.m' 'imref2d' 'align_face must set a fixed output reference for aligned faces.'
Assert-FileContains 'preprocess\translate_image.m' 'function\s+outImg\s*=\s*translate_image' 'translate_image helper is missing.'
Assert-FileContains 'preprocess\shear_image.m' 'function\s+outImg\s*=\s*shear_image' 'shear_image helper is missing.'
Assert-FileContains 'preprocess\adjust_brightness.m' 'function\s+outImg\s*=\s*adjust_brightness' 'adjust_brightness helper is missing.'
Assert-FileContains 'preprocess\flip_image.m' 'function\s+outImg\s*=\s*flip_image' 'flip_image helper is missing.'
Assert-FileContains 'preprocess\manual_select_face.m' 'function\s+faceInfo\s*=\s*manual_select_face' 'manual_select_face helper is missing.'
Assert-FileNotContains 'preprocess\manual_select_face.m' 'position\s*=\s*wait\s*\(' 'manual_select_face must not request an output from wait(roi).'
Assert-FileContains 'preprocess\manual_select_face.m' 'roi\.Position' 'manual_select_face must read the selected rectangle from roi.Position.'
Assert-FileContains 'preprocess\manual_select_face.m' 'ROIMoved' 'manual_select_face must refresh the crop after resizing the ROI.'
Assert-FileContains 'preprocess\manual_select_face.m' 'MovingROI' 'manual_select_face must refresh the crop while dragging the ROI.'
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
Assert-FileContains 'ui\create_preprocess_tab.m' 'TransformPreviewButton' 'Preprocess page must expose face detection for acceptance demo.'
Assert-FileContains 'ui\bind_callbacks.m' 'TransformPreviewButton\.ButtonPushedFcn' 'Face detection button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_detect_face' 'Face detection button must call automatic detection display.'
Assert-FileContains 'ui\bind_callbacks.m' 'TranslateButton\.ButtonPushedFcn' 'Translate button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_translate_image' 'Translate handler is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'ShearButton\.ButtonPushedFcn' 'Shear button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_shear_image' 'Shear handler is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'BrightnessButton\.ButtonPushedFcn' 'Brightness button callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_brightness_image' 'Brightness handler is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'HorizontalFlipButton' 'Horizontal flip button handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'VerticalFlipButton' 'Vertical flip button handle is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'HorizontalFlipButton\.ButtonPushedFcn' 'Horizontal flip callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'VerticalFlipButton\.ButtonPushedFcn' 'Vertical flip callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_flip_image' 'Flip handler is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'RestoreButton' 'Restore original button handle is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'RestoreButton\.ButtonPushedFcn' 'Restore original callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_restore_original_image' 'Restore original handler is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'currentRestoreImage' 'Restore source image must be tracked in app state.'
Assert-FileContains 'ui\bind_callbacks.m' 'function\s+on_restore_original_image' 'Restore original handler is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_align_face' 'Face align button must call real alignment flow.'
Assert-FileContains 'integration\action_static_predict.m' 'predict_face_identity' 'Static prediction action must call predict_face_identity.'
Assert-FileContains 'integration\action_batch_predict.m' 'run_batch_test' 'Batch action must call run_batch_test.'
Assert-FileContains 'integration\action_realtime_predict.m' 'detect_face' 'Realtime action must detect faces.'
Assert-FileContains 'integration\action_realtime_predict.m' 'predict_face_identity' 'Realtime action must call predict_face_identity.'
Assert-FileContains 'ui\bind_callbacks.m' 'lastReplayPackage\s*=\s*build_realtime_replay_package' 'Embedded realtime recognition must save a replay package for preprocess demo.'
Assert-FileContains 'ui\bind_callbacks.m' 'grayFace\s*=\s*get_optional_field' 'Replay package must carry grayscale intermediate image.'
Assert-FileContains 'ui\bind_callbacks.m' 'equalizedFace\s*=\s*get_optional_field' 'Replay package must carry equalized intermediate image.'
Assert-FileContains 'ui\bind_callbacks.m' 'serviceGrayFace' 'GUI must use 实时服务 grayscale result in replay mode.'
Assert-FileContains 'ui\bind_callbacks.m' 'serviceEqualizedFace' 'GUI must use 实时服务 equalized result in replay mode.'
Assert-FileContains 'ui\bind_callbacks.m' 'serviceAlignedFace' 'GUI must use 实时服务 aligned result in replay mode.'
Assert-FileContains 'integration\action_replay_to_preprocess.m' 'currentPreprocessBaseImage' 'Replay-to-preprocess must set the captured face as preprocessing base image.'
Assert-FileContains 'integration\action_replay_to_preprocess.m' 'preprocessMode' 'Replay-to-preprocess must mark 实时服务 replay mode.'
Assert-FileContains 'integration\action_replay_to_preprocess.m' 'faceBox' 'Replay-to-preprocess must carry the face detection box.'
Assert-FileContains 'integration\action_static_predict.m' 'defaultTestDir' 'Static prediction must open the configured test set gallery.'
Assert-FileContains 'integration\action_static_predict.m' 'load_dataset' 'Static prediction must list preprocessed test-set images.'
Assert-FileContains 'integration\action_static_predict.m' 'uifigure' 'Static prediction must show a test image selection window.'
Assert-FileNotContains 'integration\action_static_predict.m' 'uigetfile' 'Static prediction must not use the raw file picker.'
Assert-FileContains 'integration\action_static_predict.m' 'ensure_recognition_model' 'Static prediction must use the shared v11 model loader.'
Assert-FileContains 'integration\action_batch_predict.m' 'ensure_recognition_model' 'Batch prediction must use the shared v11 model loader.'
Assert-FileContains 'integration\action_realtime_predict.m' 'ensure_recognition_model' 'Realtime prediction must use the shared v11 model loader.'
Assert-FileContains 'integration\ensure_recognition_model.m' 'model_io' 'Shared model loader must load the committed model file before training fallback.'
Assert-FileContains 'config\app_config.m' 'rawFaceDir' 'App config must expose the raw face database directory.'
Assert-FileContains 'config\app_config.m' 'processedFaceDir' 'App config must expose the processed face image directory.'
Assert-FileContains 'config\app_config.m' 'final_result' 'App config must know the final_result location.'
Assert-FileContains 'config\app_config.m' 'tight_masked_pca_svm_split_v11' 'App config must expose the committed v11 split as the default database.'
Assert-FileContains 'config\app_config.m' 'pca_svm_tight_masked_v11_model' 'App config must expose the committed v11 model as the default model.'
Assert-FileContains 'integration\ensure_recognition_model.m' 'defaultTrainDir' 'Shared model loader must use configured default training directory.'
Assert-FileContains 'integration\action_batch_predict.m' 'defaultTestDir' 'Batch prediction must use configured default test directory.'
Assert-FileContains 'integration\ensure_recognition_model.m' 'defaultModelPath' 'Shared model loader must use configured default model path.'

Write-Output 'GUI design static checks passed.'
