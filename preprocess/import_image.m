function [img, imagePath] = import_image()
%IMPORT_IMAGE Pick one image from disk.

    [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff', 'Image Files'});
    if isequal(file, 0)
        img = [];
        imagePath = "";
        return;
    end
    imagePath = string(fullfile(path, file));
    img = imread(imagePath);
end

