function params = default_params()
%DEFAULT_PARAMS Shared default parameters for GUI and model flow.

    params = struct();
    params.defaultPcaDim = 120;
    params.defaultSvmC = 0.03;
    params.imageSize = [112, 92];
    params.svmMaxEpochs = 1400;
    params.svmLearningRate = 0.035;
    params.svmLearningRateDecay = 0.008;
    params.appTitle = '软萌线性代数人脸识别系统';
end

