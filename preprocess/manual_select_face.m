function faceInfo = manual_select_face(img, ax, onUpdate)
%MANUAL_SELECT_FACE Let the user draw a face rectangle on an axes.

    if nargin < 3
        onUpdate = [];
    end

    faceInfo = struct( ...
        'status', "error", ...
        'faceBox', [], ...
        'faceImage', [], ...
        'landmarks', [], ...
        'roi', [], ...
        'roiListeners', [], ...
        'message', "未开始手动框选");

    if nargin < 1 || isempty(img)
        faceInfo.status = "empty_input";
        faceInfo.message = "请先输入图像或启动摄像头。";
        return;
    end
    if nargin < 2 || isempty(ax) || ~isvalid(ax)
        faceInfo.status = "no_axes";
        faceInfo.message = "没有可用于框选的图像显示区域。";
        return;
    end

    try
        if exist('drawrectangle', 'file') ~= 2
            faceInfo.status = "unsupported";
            faceInfo.message = "当前 MATLAB 不支持 drawrectangle，请升级版本或使用自动检测。";
            return;
        end

        roi = drawrectangle(ax, ...
            'Color', [0.93 0.20 0.28], ...
            'LineWidth', 2, ...
            'StripeColor', [1.00 1.00 1.00]);
        listeners = [
            addlistener(roi, 'MovingROI', @(src, ~) notify_update(src, img, onUpdate))
            addlistener(roi, 'ROIMoved', @(src, ~) notify_update(src, img, onUpdate))
        ];
        roi.UserData = struct('roiListeners', listeners);
        notify_update(roi, img, onUpdate);

        wait(roi);
        position = roi.Position;
        if isempty(position)
            faceInfo.status = "cancelled";
            faceInfo.message = "已取消手动框选。";
            return;
        end

        faceBox = clamp_box(position, size(img));
        if faceBox(3) < 2 || faceBox(4) < 2
            faceInfo.status = "invalid_box";
            faceInfo.message = "框选区域太小，请重新框选人脸。";
            return;
        end

        faceInfo.status = "ok";
        faceInfo.faceBox = faceBox;
        faceInfo.faceImage = imcrop(img, faceBox);
        faceInfo.roi = roi;
        faceInfo.roiListeners = listeners;
        faceInfo.message = "已完成手动人脸框选。";
    catch ME
        faceInfo.status = "error";
        faceInfo.message = "手动框选失败: " + string(ME.message);
    end
end

function faceBox = clamp_box(position, imageSize)
    x = max(1, round(position(1)));
    y = max(1, round(position(2)));
    width = max(1, round(position(3)));
    height = max(1, round(position(4)));

    maxWidth = imageSize(2) - x + 1;
    maxHeight = imageSize(1) - y + 1;
    faceBox = [x, y, min(width, maxWidth), min(height, maxHeight)];
end

function notify_update(roi, img, onUpdate)
    if isempty(onUpdate) || ~isa(onUpdate, 'function_handle') || isempty(roi) || ~isvalid(roi)
        return;
    end

    faceBox = clamp_box(roi.Position, size(img));
    if faceBox(3) < 2 || faceBox(4) < 2
        return;
    end

    faceInfo = struct( ...
        'status', "ok", ...
        'faceBox', faceBox, ...
        'faceImage', imcrop(img, faceBox), ...
        'landmarks', [], ...
        'roi', roi, ...
        'roiListeners', get_roi_listeners(roi), ...
        'message', "已根据当前框选区域刷新人脸图。");
    onUpdate(faceInfo);
end

function listeners = get_roi_listeners(roi)
    listeners = [];
    if isempty(roi) || ~isvalid(roi)
        return;
    end
    data = roi.UserData;
    if isstruct(data) && isfield(data, 'roiListeners')
        listeners = data.roiListeners;
    end
end
