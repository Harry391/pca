function [frame, message] = camera_snapshot(cam)
%CAMERA_SNAPSHOT Capture one frame from an opened webcam object.

    frame = [];
    message = "";

    if nargin < 1 || isempty(cam)
        message = "摄像头尚未启动。";
        return;
    end

    try
        frame = snapshot(cam);
        message = "已捕获当前摄像头画面。";
    catch ME
        frame = [];
        message = "摄像头取帧失败: " + string(ME.message);
    end
end
