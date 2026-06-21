function ok = cleanup_runtime_services(rootDir)
%CLEANUP_RUNTIME_SERVICES Remove extracted local runtime support files.

    if nargin < 1 || isempty(rootDir)
        rootDir = fileparts(fileparts(mfilename('fullpath')));
    end

    runtimeRoot = fullfile(rootDir, '.runtime');
    ok = true;
    if ~isfolder(runtimeRoot)
        return;
    end

    remove_runtime_from_path(runtimeRoot);

    ok = false;
    for attempt = 1:8 %#ok<FXUP>
        clear_runtime_attributes(runtimeRoot);
        try
            if isfolder(runtimeRoot)
                rmdir(runtimeRoot, 's');
            end
        catch
        end

        if ~isfolder(runtimeRoot)
            ok = true;
            return;
        end
        pause(0.2);
    end
end

function remove_runtime_from_path(runtimeRoot)
    try
        runtimePaths = split_path_entries(genpath(runtimeRoot));
        activePaths = split_path_entries(path);
        for i = 1:numel(runtimePaths)
            candidate = runtimePaths{i};
            if isempty(candidate) || ~is_path_active(candidate, activePaths)
                continue;
            end
            rmpath(candidate);
        end
    catch
    end
end

function entries = split_path_entries(pathText)
    entries = regexp(pathText, pathsep, 'split');
    entries = entries(~cellfun(@isempty, entries));
end

function tf = is_path_active(candidate, activePaths)
    if ispc
        tf = any(strcmpi(candidate, activePaths));
    else
        tf = any(strcmp(candidate, activePaths));
    end
end

function clear_runtime_attributes(runtimeRoot)
    if ~ispc || ~isfolder(runtimeRoot)
        return;
    end

    try
        system(sprintf('attrib -h -r "%s"', runtimeRoot));
        system(sprintf('attrib -h -r /s /d "%s"', fullfile(runtimeRoot, '*')));
    catch
    end
end
