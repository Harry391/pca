function appState = run_main()
%RUN_MAIN Unified entry point for the PCA MATLAB face recognition project.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(rootDir, 'config')));
    addpath(genpath(fullfile(rootDir, 'ui')));
    addpath(genpath(fullfile(rootDir, 'preprocess')));
    addpath(genpath(fullfile(rootDir, 'ml')));
    addpath(genpath(fullfile(rootDir, 'integration')));

    appState = struct();
    appState.rootDir = rootDir;
    appState.currentImage = [];
    appState.currentImagePath = "";
    appState.currentGrayImage = [];
    appState.currentFaceBox = [];
    appState.currentAlignedFace = [];
    appState.currentCameraFrame = [];
    appState.lastReplayPackage = struct();
    appState.model = struct();
    appState.batchResult = struct();
    appState.singleResult = struct();
    appState.realtimeResult = struct();
    appState.datasetManifest = struct();

    params = default_params();
    appState.defaultPcaDim = params.defaultPcaDim;
    appState.defaultSvmC = params.defaultSvmC;

    handles = create_main_window(appState, params);
    bind_callbacks(handles);

    if nargout == 0
        clear appState;
    end
end

