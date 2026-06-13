function grayImg = convert_to_gray(img)
%CONVERT_TO_GRAY Convert RGB image to grayscale if needed.

    if ndims(img) == 3
        grayImg = rgb2gray(img);
    else
        grayImg = img;
    end
end

