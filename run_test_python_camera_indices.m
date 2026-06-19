function results = run_test_python_camera_indices(maxIndex)
%RUN_TEST_PYTHON_CAMERA_INDICES Probe Python/OpenCV camera access from MATLAB.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(maxIndex)
        maxIndex = 5;
    end

    pythonExe = pick_python_executable();
    scriptPath = fullfile(rootDir, 'preprocess', 'test_python_cameras.py');
    command = sprintf('"%s" "%s" --max-index %d', pythonExe, scriptPath, maxIndex);
    [status, cmdout] = system(command);
    if status ~= 0
        error('Python camera probe failed:\n%s', cmdout);
    end

    jsonText = extract_json_array(cmdout);
    results = jsondecode(jsonText);
    fprintf('Python/OpenCV camera probe results:\n');
    for i = 1:numel(results)
        item = results(i);
        fprintf('  idx=%d backend=%s opened=%d read=%d', ...
            item.index, item.backend, item.opened, item.read_ok);
        if ~isempty(item.frame_shape)
            fprintf(' shape=[%d %d %d]', item.frame_shape(1), item.frame_shape(2), item.frame_shape(3));
        end
        fprintf('\n');
    end
end

function jsonText = extract_json_array(cmdout)
    beginToken = 'JSON_BEGIN';
    endToken = 'JSON_END';
    beginIndex = strfind(cmdout, beginToken);
    endIndex = strfind(cmdout, endToken);
    if isempty(beginIndex) || isempty(endIndex)
        error('Camera probe output does not contain JSON:\n%s', cmdout);
    end
    jsonStart = beginIndex(1) + strlength(beginToken);
    jsonEnd = endIndex(end) - 1;
    jsonText = strtrim(cmdout(jsonStart:jsonEnd));
end

function pythonExe = pick_python_executable()
    envPython = strtrim(getenv('PYTHON_EXE'));
    if ~isempty(envPython)
        [status, ~] = system(['"', envPython, '" --version']);
        if status == 0
            pythonExe = envPython;
            return;
        end
    end

    if ispc
        [status, out] = system('where python');
        if status == 0
            lines = regexp(strtrim(out), '\r\n|\n|\r', 'split');
            lines = lines(~cellfun(@isempty, lines));
            if ~isempty(lines)
                pythonExe = strtrim(lines{1});
                return;
            end
        end
    end

    [status, ~] = system('python --version');
    if status == 0
        pythonExe = 'python';
        return;
    end

    error('No usable python executable found. Set PYTHON_EXE first.');
end
