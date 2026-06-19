function params = default_params()
%DEFAULT_PARAMS Shared default parameters for GUI and model flow.

    params = struct();
    params.defaultPcaDim = 30;
    params.defaultSvmC = 1.0;
    params.imageSize = [112, 92];
    params.appTitle = '软萌线性代数人脸识别系统';
end

