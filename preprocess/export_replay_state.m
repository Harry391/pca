function replayPkg = export_replay_state(rawFrame, faceInfo, alignInfo)
%EXPORT_REPLAY_STATE Bundle runtime face data for preprocess replay.

    replayPkg = struct();
    replayPkg.rawFrame = rawFrame;
    replayPkg.faceBox = faceInfo.faceBox;
    replayPkg.faceImage = faceInfo.faceImage;
    replayPkg.alignedFace = alignInfo.alignedFace;
    replayPkg.landmarks = faceInfo.landmarks;
    replayPkg.timestamp = datetime('now');
end

