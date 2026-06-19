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
Assert-FileContains 'ui\create_recognition_tab.m' 'RealtimeRecordsTable' 'Realtime records table handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'Mascot' 'Preprocess mascot decoration handle is missing.'
Assert-FileContains 'ui\create_recognition_tab.m' 'Mascot' 'Recognition mascot decoration handle is missing.'
Assert-FileContains 'ui\load_ui_assets.m' 'leftCorner' 'Left corner decoration asset is missing.'
Assert-FileContains 'ui\load_ui_assets.m' 'rightCornerBlue' 'Right blue corner decoration asset is missing.'
Assert-FileContains 'ui\initialize_empty_axes.m' 'function\s+initialize_empty_axes' 'Empty axes helper is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'initialize_empty_axes' 'Preprocess tab must keep image display axes empty.'
Assert-FileContains 'ui\create_recognition_tab.m' 'initialize_empty_axes' 'Recognition tab must keep image display axes empty.'
Assert-FileContains 'ui\bind_callbacks.m' 'ImportButton\.ButtonPushedFcn' 'Import image callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'GrayButton\.ButtonPushedFcn' 'Gray conversion callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'EqualizeButton\.ButtonPushedFcn' 'Equalization callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'StatsButton\.ButtonPushedFcn' 'Image stats callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'BatchTestButton\.ButtonPushedFcn' 'Batch test callback is missing.'
Assert-FileContains 'ui\bind_callbacks.m' 'RealtimePredictButton\.ButtonPushedFcn' 'Realtime recognition callback is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'InputAxes' 'Original/captured image axes handle is missing.'
Assert-FileContains 'ui\create_preprocess_tab.m' 'ProcessedAxes' 'Processed image axes handle is missing.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'ExternalFigureDropDown' 'External figure selector should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'BrightenButton' 'Brighten special-effect button should be removed.'
Assert-FileNotContains 'ui\create_preprocess_tab.m' 'StickerButton' 'Sticker special-effect button should be removed.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'BrightenButton' 'Removed brighten button must not be bound.'
Assert-FileNotContains 'ui\bind_callbacks.m' 'StickerButton' 'Removed sticker button must not be bound.'
Assert-FileContains 'preprocess\camera_start.m' 'webcam' 'camera_start must attempt to use MATLAB webcam.'
Assert-FileContains 'preprocess\camera_snapshot.m' 'snapshot' 'camera_snapshot must capture a frame.'
Assert-FileContains 'preprocess\detect_face.m' 'CascadeObjectDetector' 'detect_face must use CascadeObjectDetector when available.'
Assert-FileContains 'preprocess\align_face.m' 'imresize' 'align_face must resize aligned faces.'
Assert-FileNotContains 'preprocess\detect_face.m' 'detect_face not implemented' 'detect_face placeholder message must be removed.'
Assert-FileNotContains 'preprocess\align_face.m' 'align_face not implemented' 'align_face placeholder message must be removed.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_start_camera' 'Start camera button must call real camera flow.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_detect_face' 'Face select button must call real detection flow.'
Assert-FileContains 'ui\bind_callbacks.m' 'on_align_face' 'Face align button must call real alignment flow.'
Assert-FileContains 'integration\action_static_predict.m' 'predict_face_identity' 'Static prediction action must call predict_face_identity.'
Assert-FileContains 'integration\action_batch_predict.m' 'run_batch_test' 'Batch action must call run_batch_test.'
Assert-FileContains 'integration\action_realtime_predict.m' 'detect_face' 'Realtime action must detect faces.'
Assert-FileContains 'integration\action_realtime_predict.m' 'predict_face_identity' 'Realtime action must call predict_face_identity.'

Write-Output 'GUI design static checks passed.'
