function outDir = run_batch_align_raw_faces(rawDir, outDir, maxImages)
%RUN_BATCH_ALIGN_RAW_FACES Align every face in a raw folder and export per-person files.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(rawDir)
        rawDir = fullfile(fileparts(rootDir), '人脸识别');
    end
    if nargin < 2 || isempty(outDir)
        outDir = fullfile(rootDir, 'data', 'matlab_landmark_aligned_raw_faces');
    end
    if nargin < 3 || isempty(maxImages)
        maxImages = inf;
    end

    if ~isfolder(outDir)
        mkdir(outDir);
    end

    imagePaths = collect_images(rawDir);
    if isempty(imagePaths)
        error('No images found in %s', rawDir);
    end

    if isfinite(maxImages)
        imagePaths = imagePaths(1:min(numel(imagePaths), maxImages));
    end

    total = numel(imagePaths);
    fprintf('批量对齐开始: %s -> %s, 共 %d 张\n', rawDir, outDir, total);

    manifestPath = fullfile(outDir, 'alignment_manifest.csv');
    fid = fopen(manifestPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'source_path,output_path,label,status,message\n');

    for i = 1:total
        sourcePath = imagePaths{i};
        [~, stem, ext] = fileparts(sourcePath);
        label = normalize_label(stem);

        personDir = fullfile(outDir, label);
        if ~isfolder(personDir)
            mkdir(personDir);
        end

        img = imread(sourcePath);
        faceInfo = detect_face(img, struct('detectorMode', 'fast', 'useEqualizedSearch', false, 'minFaceRatio', 0.68, 'facePadding', 0.32));
        alignInfo = align_face(img, faceInfo, struct('imageSize', [112, 92]));

        outputPath = fullfile(personDir, sprintf('%s_aligned.png', stem));
        if strcmpi(ext, '.jpg') || strcmpi(ext, '.jpeg')
            outputPath = fullfile(personDir, sprintf('%s_aligned.jpg', stem));
        end
        imwrite(im2uint8(alignInfo.alignedFace), outputPath);

        fprintf(fid, '%s,%s,%s,%s,%s\n', csv_escape(sourcePath), csv_escape(outputPath), ...
            csv_escape(label), csv_escape(alignInfo.status), csv_escape(faceInfo.message));

        fprintf('%04d/%04d %s -> %s | %s\n', i, total, label, outputPath, faceInfo.message);
    end

    clear cleanup;
    fprintf('批量对齐完成: %s\n', outDir);
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

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
