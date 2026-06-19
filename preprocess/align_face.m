function alignInfo = align_face(img, faceInfo, options)
%ALIGN_FACE Produce a stable grayscale face image with the configured size.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'imageSize') || isempty(options.imageSize)
        options.imageSize = [112, 92];
    end

    alignInfo = struct( ...
        'status', "error", ...
        'alignedFace', [], ...
        'transformInfo', [], ...
        'message', "未开始校准");

    try
        faceImg = [];
        if nargin >= 2 && isstruct(faceInfo) && isfield(faceInfo, 'faceImage') && ~isempty(faceInfo.faceImage)
            faceImg = faceInfo.faceImage;
        elseif nargin >= 1 && ~isempty(img)
            faceImg = img;
        end

        if isempty(faceImg)
            alignInfo.status = "empty_input";
            alignInfo.message = "没有可校准的人脸图像。";
            return;
        end

        grayFace = convert_to_gray(faceImg);
        alignedFace = imresize(grayFace, options.imageSize);

        alignInfo.status = "ok";
        alignInfo.alignedFace = alignedFace;
        alignInfo.transformInfo = struct( ...
            'method', "crop_gray_resize", ...
            'imageSize', options.imageSize);
        alignInfo.message = sprintf('已校准为 %dx%d 灰度人脸。', options.imageSize(1), options.imageSize(2));
    catch ME
        alignInfo.status = "error";
        alignInfo.message = "人脸校准失败: " + string(ME.message);
    end
end
