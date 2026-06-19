function run_matlab_preprocess_preview(imagePath)
%RUN_MATLAB_PREPROCESS_PREVIEW Compare raw image and MATLAB preprocessing output.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(imagePath)
        [f, p] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'});
        if isequal(f, 0)
            return;
        end
        imagePath = fullfile(p, f);
    end

    img = imread(imagePath);
    faceInfo = detect_face(img, struct('useEqualizedSearch', true));
    alignInfo = align_face(img, faceInfo, struct('imageSize', [112, 92]));

    figure('Name', 'MATLAB Preprocess Preview', 'NumberTitle', 'off', 'Color', 'w');
    subplot(1, 3, 1);
    imshow(img, []);
    title('Raw');

    subplot(1, 3, 2);
    imshow(faceInfo.faceImage, []);
    title(sprintf('Face Box | %s', faceInfo.message), 'Interpreter', 'none');

    subplot(1, 3, 3);
    imshow(alignInfo.alignedFace, []);
    title(sprintf('Aligned | %s', alignInfo.message), 'Interpreter', 'none');
end
