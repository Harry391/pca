function galleryPath = run_matlab_preprocess_gallery(rawDir, maxImages)
%RUN_MATLAB_PREPROCESS_GALLERY Build a side-by-side preview for raw faces.
%
% Columns: raw image | detected face crop | aligned face
%
% Usage:
%   run_matlab_preprocess_gallery
%   run_matlab_preprocess_gallery('D:\Brightmoon\Liner algebra\人脸识别', 12)

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(rawDir)
        rawDir = fullfile(fileparts(rootDir), '人脸识别');
    end
    if nargin < 2 || isempty(maxImages)
        maxImages = 12;
    end

    imagePaths = collect_images(rawDir);
    if isempty(imagePaths)
        error('No images found in %s', rawDir);
    end

    maxImages = min(maxImages, numel(imagePaths));
    imagePaths = imagePaths(1:maxImages);

    cellRows = cell(maxImages, 3);
    for i = 1:maxImages
        img = imread(imagePaths{i});
        faceInfo = detect_face(img, struct('useEqualizedSearch', true, 'minFaceRatio', 0.45));
        alignInfo = align_face(img, faceInfo, struct('imageSize', [112, 92]));

        cellRows{i, 1} = annotate_image(img, sprintf('%d Raw', i));
        cellRows{i, 2} = annotate_image(faceInfo.faceImage, sprintf('%d Face | %s', i, faceInfo.message));
        cellRows{i, 3} = annotate_image(alignInfo.alignedFace, sprintf('%d Aligned | %s', i, alignInfo.message));
    end

    fig = figure('Name', 'MATLAB Preprocess Gallery', 'NumberTitle', 'off', 'Color', 'w');
    tiledlayout(maxImages, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
    for r = 1:maxImages
        for c = 1:3
            nexttile;
            imshow(cellRows{r, c}, []);
        end
    end

    outDir = fullfile(rootDir, 'results');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    galleryPath = fullfile(outDir, 'matlab_preprocess_gallery.png');
    exportgraphics(fig, galleryPath, 'Resolution', 160);
    fprintf('Gallery saved: %s\n', galleryPath);
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

function out = annotate_image(img, labelText)
    if isempty(img)
        img = uint8(255 * ones(112, 92));
    end
    if ndims(img) == 2
        img = repmat(img, 1, 1, 3);
    end
    out = img;
    if exist('insertText', 'file') == 2
        out = insertText(out, [5 5], labelText, 'FontSize', 14, 'TextColor', 'white', ...
            'BoxColor', 'black', 'BoxOpacity', 0.7);
    end
end
