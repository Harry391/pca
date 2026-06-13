function outImg = equalize_image(img)
%EQUALIZE_IMAGE Histogram equalization helper.

    grayImg = convert_to_gray(img);
    outImg = histeq(grayImg);
end

