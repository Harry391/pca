function result = action_replay_to_preprocess(state, params)
%ACTION_REPLAY_TO_PREPROCESS Return the latest realtime package for UI replay.

    %#ok<INUSD>
    result = struct('status', "error", 'message', "没有可回放的人脸采集结果。", ...
        'appState', state, 'rawFrame', [], 'alignedFace', []);

    if ~isfield(state, 'lastReplayPackage') || isempty(state.lastReplayPackage) || ...
            ~isstruct(state.lastReplayPackage) || ~isfield(state.lastReplayPackage, 'rawFrame') || ...
            isempty(state.lastReplayPackage.rawFrame)
        result.status = "empty";
        return;
    end

    replayPkg = state.lastReplayPackage;
    faceBox = get_field_or(replayPkg, 'faceBox', []);
    faceImage = get_field_or(replayPkg, 'faceImage', []);
    if isempty(faceImage)
        faceImage = replayPkg.alignedFace;
    end
    serviceGrayFace = get_field_or(replayPkg, 'serviceGrayFace', []);
    serviceEqualizedFace = get_field_or(replayPkg, 'serviceEqualizedFace', []);
    serviceAlignedFace = get_field_or(replayPkg, 'serviceAlignedFace', replayPkg.alignedFace);
    serviceAlignedColor = get_field_or(replayPkg, 'serviceAlignedColor', []);

    state.currentImage = replayPkg.rawFrame;
    state.currentCameraFrame = replayPkg.rawFrame;
    state.preprocessMode = "runtime_service";
    state.serviceFaceImage = faceImage;
    state.serviceGrayFace = serviceGrayFace;
    state.serviceEqualizedFace = serviceEqualizedFace;
    state.serviceAlignedFace = serviceAlignedFace;
    state.serviceAlignedColor = serviceAlignedColor;
    state.currentFaceBox = faceBox;
    state.currentFaceInfo = struct( ...
        'status', "ok", ...
        'faceBox', faceBox, ...
        'faceImage', faceImage, ...
        'faceColorImage', get_field_or(replayPkg, 'faceColorImage', faceImage), ...
        'landmarks', get_field_or(replayPkg, 'landmarks', struct()), ...
        'message', "实时服务 MediaPipe 人脸检测结果");
    state.currentAlignInfo = struct( ...
        'status', "ok", ...
        'alignedFace', serviceAlignedFace, ...
        'transformInfo', struct('method', "runtime_service_tight_masked"), ...
        'message', "实时服务 眼-眼-嘴仿射配准 + CLAHE + 软遮罩");
    state.currentAlignedFace = serviceAlignedFace;
    state.currentProcessedImage = serviceAlignedFace;
    state.currentPreprocessBaseImage = faceImage;
    state.currentPreprocessBaseLabel = "实时服务 检测到的人脸";
    state.currentRestoreImage = faceImage;
    state.currentRestoreLabel = "实时服务 检测到的人脸";

    result.status = "ok";
    result.message = "已送入预处理页：左侧为采集原图和检测框，右侧为配准后人脸；可继续展示灰度、几何运算和人脸校准。";
    result.appState = state;
    result.rawFrame = replayPkg.rawFrame;
    result.faceBox = faceBox;
    result.faceImage = faceImage;
    result.alignedFace = serviceAlignedFace;
end

function value = get_field_or(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName)
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end
