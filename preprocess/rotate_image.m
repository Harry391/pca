function outImg = rotate_image(img, angleDeg)
%ROTATE_IMAGE Rotate image by angle in degrees.

    outImg = imrotate(img, angleDeg, 'bilinear', 'crop');
end

