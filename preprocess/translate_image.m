function outImg = translate_image(img, offset)
%TRANSLATE_IMAGE Shift an image by [dx, dy] pixels while preserving size.

    [dx, dy] = parse_offset(offset);
    dx = round(dx);
    dy = round(dy);

    try
        if exist('imtranslate', 'file') == 2
            outImg = imtranslate(img, [dx dy], 'OutputView', 'same', 'FillValues', 0);
            return;
        end
    catch
    end

    outImg = zeros(size(img), 'like', img);
    [height, width, ~] = size(img);

    srcX1 = max(1, 1 - dx);
    srcX2 = min(width, width - dx);
    dstX1 = max(1, 1 + dx);
    dstX2 = min(width, width + dx);

    srcY1 = max(1, 1 - dy);
    srcY2 = min(height, height - dy);
    dstY1 = max(1, 1 + dy);
    dstY2 = min(height, height + dy);

    if srcX1 <= srcX2 && srcY1 <= srcY2
        outImg(dstY1:dstY2, dstX1:dstX2, :) = img(srcY1:srcY2, srcX1:srcX2, :);
    end
end

function [dx, dy] = parse_offset(offset)
    if nargin < 1 || isempty(offset)
        dx = 0;
        dy = 0;
        return;
    end

    if isnumeric(offset)
        values = offset(:);
    else
        text = strrep(char(string(offset)), '，', ',');
        parts = regexp(text, '[,\s]+', 'split');
        values = str2double(parts(~cellfun('isempty', parts)));
    end

    if numel(values) < 2 || any(isnan(values(1:2)))
        error('translate_image:InvalidOffset', '平移参数应为 dx,dy，例如 20,-10。');
    end

    dx = values(1);
    dy = values(2);
end
