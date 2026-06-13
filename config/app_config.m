function cfg = app_config(rootDir)
%APP_CONFIG Shared paths and runtime configuration.

    if nargin < 1 || isempty(rootDir)
        rootDir = fileparts(fileparts(mfilename('fullpath')));
    end

    cfg = struct();
    cfg.rootDir = rootDir;
    cfg.dataDir = fullfile(rootDir, 'data');
    cfg.modelsDir = fullfile(rootDir, 'models');
    cfg.resultsDir = fullfile(rootDir, 'results');
    cfg.docsDir = fullfile(rootDir, 'docs');
end

