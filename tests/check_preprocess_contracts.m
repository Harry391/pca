function check_preprocess_contracts()
%CHECK_PREPROCESS_CONTRACTS Lightweight contract checks for A-side functions.

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

    cfg = app_config(rootDir);
    assert(endsWith(string(cfg.rawFaceDir), "人脸识别"), 'rawFaceDir should point to 人脸识别.');
    assert(contains(string(cfg.processedFaceDir), "final_result"), 'processedFaceDir should point to final_result.');

    rgb = uint8(ones(80, 60, 3) .* 180);
    faceInfo = struct( ...
        'status', "ok", ...
        'faceBox', [1 1 60 80], ...
        'faceImage', rgb, ...
        'landmarks', [], ...
        'message', "synthetic face");

    alignInfo = align_face(rgb, faceInfo, struct('imageSize', [112, 92]));
    assert(string(alignInfo.status) == "ok", 'align_face should return ok for synthetic face.');
    assert(isequal(size(alignInfo.alignedFace), [112 92]), 'align_face must resize to 112x92 grayscale.');

    translated = translate_image(rgb, [8, -4]);
    assert(isequal(size(translated), size(rgb)), 'translate_image should preserve image size.');
    assert(strcmp(class(translated), class(rgb)), 'translate_image should preserve image class.');

    scaled = scale_image(rgb, 0.5);
    assert(isequal(size(scaled, 3), size(rgb, 3)), 'scale_image should preserve channel count.');

    sheared = shear_image(rgb, 0.25);
    assert(isequal(size(sheared), size(rgb)), 'shear_image should preserve image size.');
    assert(strcmp(class(sheared), class(rgb)), 'shear_image should preserve image class.');

    brighter = adjust_brightness(uint8([0 128 255]), 40);
    assert(isequal(brighter, uint8([40 168 255])), 'adjust_brightness should add and clamp uint8 values.');

    darker = adjust_brightness(uint8([0 128 255]), -40);
    assert(isequal(darker, uint8([0 88 215])), 'adjust_brightness should subtract and clamp uint8 values.');

    flippedHorizontal = flip_image(rgb, 'horizontal');
    assert(isequal(flippedHorizontal(:, 1, :), rgb(:, end, :)), 'flip_image horizontal should mirror columns.');

    flippedVertical = flip_image(rgb, 'vertical');
    assert(isequal(flippedVertical(1, :, :), rgb(end, :, :)), 'flip_image vertical should mirror rows.');

    emptyInfo = detect_face([], struct());
    assert(string(emptyInfo.status) == "empty_input", 'detect_face must handle empty input.');

    appState = struct();
    appState.rootDir = rootDir;
    appState.defaultTrainDir = cfg.defaultTrainDir;
    appState.defaultTestDir = cfg.defaultTestDir;
    appState.currentImage = rgb;
    appState.currentCameraFrame = [];
    appState.camera = [];
    appState.model = struct();
    appState.defaultPcaDim = 30;
    appState.defaultSvmC = 1;

    result = action_realtime_predict(appState, struct('pcaDim', 30, 'svmC', 1));
    assert(isfield(result, 'status'), 'Realtime action must return a status field.');
    assert(isfield(result, 'message'), 'Realtime action must return a message field.');

    disp('Preprocess contract checks passed.');
end
