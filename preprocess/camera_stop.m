function message = camera_stop(cam)
%CAMERA_STOP Release a MATLAB webcam object.

    message = "摄像头已停止。";
    if nargin < 1 || isempty(cam)
        message = "摄像头未启动。";
        return;
    end

    try
        clear cam;
    catch ME
        message = "摄像头停止时出现问题: " + string(ME.message);
    end
end
