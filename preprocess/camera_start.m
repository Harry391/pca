function [cam, message] = camera_start(cameraName)
%CAMERA_START Open the default MATLAB webcam with graceful failure.

    cam = [];
    message = "";

    try
        if exist('webcam', 'file') ~= 2
            message = "未检测到 MATLAB webcam 支持包，请安装 USB Webcam Support Package。";
            return;
        end

        names = webcamlist;
        if isempty(names)
            message = "未找到可用摄像头。";
            return;
        end

        if nargin >= 1 && ~isempty(cameraName)
            cam = webcam(cameraName);
        else
            cam = webcam(1);
        end
        message = "摄像头已启动。";
    catch ME
        cam = [];
        message = "摄像头启动失败: " + string(ME.message);
    end
end
