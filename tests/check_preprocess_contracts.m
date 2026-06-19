function check_preprocess_contracts()
%CHECK_PREPROCESS_CONTRACTS Lightweight contract checks for A-side functions.

    rootDir = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(rootDir));

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

    emptyInfo = detect_face([], struct());
    assert(string(emptyInfo.status) == "empty_input", 'detect_face must handle empty input.');

    appState = struct();
    appState.rootDir = rootDir;
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
