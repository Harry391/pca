function outImg = shear_image(img, shearValue)
%SHEAR_IMAGE Horizontally shear an image while preserving size.

    shearValue = parse_shear_value(shearValue);

    try
        if exist('affine2d', 'file') == 2 && exist('imwarp', 'file') == 2
            tform = affine2d([1 0 0; shearValue 1 0; 0 0 1]);
            outView = imref2d([size(img, 1), size(img, 2)]);
            outImg = imwarp(img, tform, 'OutputView', outView, 'FillValues', 0);
            return;
        end
    catch
    end

    outImg = zeros(size(img), 'like', img);
    [height, width, channels] = size(img);
    centerY = (height + 1) / 2;

    for y = 1:height
        srcX = round((1:width) - shearValue * (y - centerY));
        valid = srcX >= 1 & srcX <= width;
        if any(valid)
            for c = 1:channels
                row = outImg(y, :, c);
                sourceRow = img(y, :, c);
                row(valid) = sourceRow(srcX(valid));
                outImg(y, :, c) = row;
            end
        end
    end
end

function shearValue = parse_shear_value(value)
    if nargin < 1 || isempty(value)
        shearValue = 0;
    elseif isnumeric(value)
        shearValue = value(1);
    else
        shearValue = str2double(strrep(char(string(value)), '，', '.'));
    end

    if isnan(shearValue)
        error('shear_image:InvalidValue', '切变参数应为数字，例如 0.2。');
    end
end
