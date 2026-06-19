function outImg = equalize_image(img)
%EQUALIZE_IMAGE Histogram equalization helper.

    grayImg = convert_to_gray(img);
    grayImg = im2double(grayImg);
    if exist('adapthisteq', 'file') == 2
        outImg = adapthisteq(grayImg, 'ClipLimit', 0.02, 'NumTiles', [8 8]);
    else
        outImg = histeq(im2uint8(grayImg));
        outImg = im2double(outImg);
    end
end
