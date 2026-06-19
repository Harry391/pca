function outDir = run_matlab_manual_align_raw_faces(rawDir, outDir, maxImages, overwrite)
%RUN_MATLAB_MANUAL_ALIGN_RAW_FACES Manually align raw faces in MATLAB.
%
% Click order: left eye, right eye, mouth.
%
% Usage:
%   run_matlab_manual_align_raw_faces
%   run_matlab_manual_align_raw_faces([], [], 5)
%   run_matlab_manual_align_raw_faces('D:\Brightmoon\Liner algebra\人脸识别')

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(rawDir)
        rawDir = fullfile(fileparts(rootDir), '人脸识别');
    end
    if nargin < 2 || isempty(outDir)
        outDir = fullfile(rootDir, 'data', 'matlab_manual_aligned_raw_faces');
    end
    if nargin < 3 || isempty(maxImages)
        maxImages = inf;
    end
    if nargin < 4 || isempty(overwrite)
        overwrite = false;
    end

    if ~isfolder(outDir)
        mkdir(outDir);
    end

    imagePaths = collect_images(rawDir);
    if isfinite(maxImages)
        imagePaths = imagePaths(1:min(numel(imagePaths), maxImages));
    end
    if isempty(imagePaths)
        error('No images found in %s', rawDir);
    end

    manifestPath = fullfile(outDir, 'manual_alignment_manifest.csv');
    ensure_manifest_header(manifestPath);

    fprintf('MATLAB manual alignment\n');
    fprintf('Source: %s\n', rawDir);
    fprintf('Output: %s\n', outDir);
    fprintf('Count: %d\n', numel(imagePaths));
    fprintf('Click order: left eye, right eye, mouth.\n');

    for i = 1:numel(imagePaths)
        sourcePath = imagePaths{i};
        [~, stem, ext] = fileparts(sourcePath);
        label = normalize_label(stem);
        personDir = fullfile(outDir, label);
        if ~isfolder(personDir)
            mkdir(personDir);
        end

        outputPath = fullfile(personDir, sprintf('%s_manual_aligned.png', stem));
        if strcmpi(ext, '.jpg') || strcmpi(ext, '.jpeg')
            outputPath = fullfile(personDir, sprintf('%s_manual_aligned.jpg', stem));
        end

        if isfile(outputPath) && ~overwrite
            fprintf('%04d/%04d skipped existing: %s\n', i, numel(imagePaths), outputPath);
            continue;
        end

        img = imread(sourcePath);
        action = 'redo';
        while strcmp(action, 'redo')
            [points, wasQuit] = collect_points(img, sprintf('%04d/%04d %s', i, numel(imagePaths), stem));
            if wasQuit
                fprintf('User quit. Output remains in: %s\n', outDir);
                return;
            end
            if isempty(points)
                fprintf('%04d/%04d skipped: %s\n', i, numel(imagePaths), sourcePath);
                break;
            end

            alignInfo = align_face_from_points(img, points, [112, 92]);
            action = preview_alignment(img, points, alignInfo.alignedFace, stem);
            if strcmp(action, 'save')
                imwrite(im2uint8(alignInfo.alignedFace), outputPath);
                append_manifest_row(manifestPath, sourcePath, outputPath, label, points);
                fprintf('%04d/%04d saved: %s\n', i, numel(imagePaths), outputPath);
            elseif strcmp(action, 'quit')
                fprintf('User quit. Output remains in: %s\n', outDir);
                return;
            elseif strcmp(action, 'skip')
                fprintf('%04d/%04d skipped: %s\n', i, numel(imagePaths), sourcePath);
            end
        end
    end

    fprintf('Manual alignment completed: %s\n', outDir);
end

function [points, wasQuit] = collect_points(img, titleText)
    wasQuit = false;
    points = [];

    fig = figure('Name', titleText, 'NumberTitle', 'off', 'Color', 'w');
    imshow(img, []);
    title({'Click: left eye -> right eye -> mouth', 'Press Enter before 3 points to skip'}, 'Interpreter', 'none');
    hold on;

    [x, y, button] = ginput(3); %#ok<ASGLU>
    if ~ishandle(fig)
        wasQuit = true;
        return;
    end
    close(fig);

    if numel(x) < 3
        points = [];
        return;
    end
    points = [x(:), y(:)];
end

function action = preview_alignment(img, points, alignedFace, stem)
    fig = figure('Name', ['Preview ' stem], 'NumberTitle', 'off', 'Color', 'w');
    subplot(1, 2, 1);
    imshow(img, []);
    hold on;
    plot(points(:, 1), points(:, 2), 'g+', 'MarkerSize', 12, 'LineWidth', 2);
    text(points(:, 1) + 6, points(:, 2), {'left eye', 'right eye', 'mouth'}, ...
        'Color', 'yellow', 'FontSize', 10, 'FontWeight', 'bold');
    title('Clicked points', 'Interpreter', 'none');

    subplot(1, 2, 2);
    imshow(alignedFace, []);
    title('Aligned output', 'Interpreter', 'none');

    choice = menu('Preview result', 'Save', 'Redo points', 'Skip this image', 'Quit');
    if ishandle(fig)
        close(fig);
    end

    if choice == 1
        action = 'save';
    elseif choice == 2
        action = 'redo';
    elseif choice == 3
        action = 'skip';
    else
        action = 'quit';
    end
end

function imagePaths = collect_images(rawDir)
    suffixes = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff'};
    files = [];
    for i = 1:numel(suffixes)
        files = [files; dir(fullfile(rawDir, '**', suffixes{i}))]; %#ok<AGROW>
    end
    imagePaths = cell(1, numel(files));
    for i = 1:numel(files)
        imagePaths{i} = fullfile(files(i).folder, files(i).name);
    end
end

function label = normalize_label(stem)
    label = strtrim(stem);
    label = regexprep(label, '\s*\(\d+\)$', '');
    underscore = strfind(label, '_');
    if ~isempty(underscore)
        label = label(1:underscore(1) - 1);
    end
    label = regexprep(label, '\d+$', '');
    if strcmp(label, '刘驿恺')
        label = '刘毅凯';
    end
end

function ensure_manifest_header(manifestPath)
    if isfile(manifestPath) && dir(manifestPath).bytes > 0
        return;
    end

    fid = fopen(manifestPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'source_path,output_path,label,left_eye_x,left_eye_y,right_eye_x,right_eye_y,mouth_x,mouth_y\n');
    clear cleanup;
end

function append_manifest_row(manifestPath, sourcePath, outputPath, label, points)
    fid = fopen(manifestPath, 'a', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n', ...
        csv_escape(sourcePath), csv_escape(outputPath), csv_escape(label), ...
        points(1, 1), points(1, 2), points(2, 1), points(2, 2), points(3, 1), points(3, 2));
    clear cleanup;
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
