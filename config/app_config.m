function cfg = app_config(rootDir)
%APP_CONFIG Shared paths and runtime configuration.

    if nargin < 1 || isempty(rootDir)
        rootDir = fileparts(fileparts(mfilename('fullpath')));
    end

    cfg = struct();
    cfg.rootDir = rootDir;
    cfg.projectDir = fileparts(rootDir);
    cfg.dataDir = fullfile(rootDir, 'data');
    cfg.rawFaceDir = fullfile(cfg.projectDir, '人脸识别');
    cfg.processedFaceDir = resolve_processed_face_dir(cfg.projectDir);
    cfg.modelsDir = fullfile(rootDir, 'models');
    cfg.resultsDir = fullfile(rootDir, 'results');
    cfg.docsDir = fullfile(rootDir, 'docs');
    cfg.defaultSplitDir = fullfile(cfg.dataDir, 'python_tight_masked_pca_svm_split_v11');
    cfg.defaultTrainDir = fullfile(cfg.defaultSplitDir, 'train');
    cfg.defaultTestDir = fullfile(cfg.defaultSplitDir, 'test');
    cfg.defaultModelPath = fullfile(cfg.modelsDir, 'pca_svm_tight_masked_v11_model.mat');
end

function processedFaceDir = resolve_processed_face_dir(projectDir)
    nestedDir = fullfile(projectDir, 'final_result', 'final_result');
    flatDir = fullfile(projectDir, 'final_result');

    if isfolder(nestedDir)
        processedFaceDir = nestedDir;
    else
        processedFaceDir = flatDir;
    end
end

