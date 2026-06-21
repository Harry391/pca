function runtimeDir = add_runtime_services(rootDir)
%ADD_RUNTIME_SERVICES Add hidden runtime service helpers to the MATLAB path.

    if nargin < 1 || isempty(rootDir)
        rootDir = fileparts(fileparts(mfilename('fullpath')));
    end

    runtimeRoot = fullfile(rootDir, '.runtime');
    runtimeDir = fullfile(runtimeRoot, 'matlab');
    if ~isfolder(runtimeDir)
        restore_runtime_support(rootDir, runtimeRoot);
    end

    if isfolder(runtimeDir)
        addpath(genpath(runtimeDir));
    end
end

function restore_runtime_support(rootDir, runtimeRoot)
    archivePath = fullfile(rootDir, 'assets', 'runtime_support.dat');
    if ~isfile(archivePath)
        return;
    end

    if ~isfolder(runtimeRoot)
        mkdir(runtimeRoot);
    end

    unzip(archivePath, runtimeRoot);
    try
        if ispc
            fileattrib(runtimeRoot, '+h');
        end
    catch
    end
end
