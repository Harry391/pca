function appState = run_main()
%RUN_MAIN Unified entry point for the PCA MATLAB face recognition project.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(rootDir, 'config')));
    addpath(genpath(fullfile(rootDir, 'ui')));
    addpath(genpath(fullfile(rootDir, 'preprocess')));
    addpath(genpath(fullfile(rootDir, 'ml')));
    addpath(genpath(fullfile(rootDir, 'integration')));
    add_runtime_services(rootDir);

    cfg = app_config(rootDir);

    appState = struct();
    appState.rootDir = rootDir;
    appState.config = cfg;
    appState.rawFaceDir = cfg.rawFaceDir;
    appState.processedFaceDir = cfg.processedFaceDir;
    appState.defaultTrainDir = cfg.defaultTrainDir;
    appState.defaultTestDir = cfg.defaultTestDir;
    appState.defaultModelPath = cfg.defaultModelPath;
    appState.currentImage = [];
    appState.currentImagePath = "";
    appState.currentPreprocessBaseImage = [];
    appState.currentPreprocessBaseLabel = "";
    appState.currentRestoreImage = [];
    appState.currentRestoreLabel = "";
    appState.preprocessMode = "";
    appState.serviceFaceImage = [];
    appState.serviceGrayFace = [];
    appState.serviceEqualizedFace = [];
    appState.serviceAlignedFace = [];
    appState.serviceAlignedColor = [];
    appState.currentGrayImage = [];
    appState.currentProcessedImage = [];
    appState.currentFaceBox = [];
    appState.currentFaceInfo = struct();
    appState.currentFaceRoi = [];
    appState.currentFaceRoiListeners = [];
    appState.currentAlignInfo = struct();
    appState.currentAlignedFace = [];
    appState.currentCameraFrame = [];
    appState.camera = [];
    appState.cameraTimer = [];
    appState.realtimeBridge = struct();
    appState.realtimeBridgeTimer = [];
    appState.realtimeLastSequence = -1;
    appState.realtimeFps = 0;
    appState.realtimeLastTic = [];
    appState.lastReplayPackage = struct();
    appState.model = struct();
    appState.batchResult = struct();
    appState.singleResult = struct();
    appState.realtimeResult = struct();
    appState.datasetManifest = struct();

    params = default_params();
    theme = get_ui_theme();
    assets = load_ui_assets(rootDir);
    appState.defaultPcaDim = params.defaultPcaDim;
    appState.defaultSvmC = params.defaultSvmC;
    appState.defaultSvmMaxEpochs = params.svmMaxEpochs;
    appState.defaultSvmLearningRate = params.svmLearningRate;
    appState.defaultSvmLearningRateDecay = params.svmLearningRateDecay;

    handles = create_main_window(appState, params, theme, assets);
    handles.Figure.UserData = appState;
    bind_callbacks(handles);

    if nargout == 0
        clear appState;
    end
end

