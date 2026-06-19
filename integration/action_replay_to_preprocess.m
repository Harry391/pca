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
    state.currentImage = replayPkg.rawFrame;
    state.currentCameraFrame = replayPkg.rawFrame;
    state.currentFaceBox = replayPkg.faceBox;
    state.currentAlignedFace = replayPkg.alignedFace;
    state.currentProcessedImage = replayPkg.alignedFace;

    result.status = "ok";
    result.message = "已送入预处理页，可继续展示灰度、几何运算和参数统计。";
    result.appState = state;
    result.rawFrame = replayPkg.rawFrame;
    result.alignedFace = replayPkg.alignedFace;
end
