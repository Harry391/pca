function outImg = flip_image(img, mode)
%FLIP_IMAGE Flip an image vertically or horizontally.

    if nargin < 2 || isempty(mode)
        mode = 'vertical';
    end

    mode = lower(string(mode));
    switch mode
        case {"vertical", "垂直"}
            outImg = flipud(img);
        case {"horizontal", "水平"}
            outImg = fliplr(img);
        otherwise
            error('flip_image:InvalidMode', '翻转模式应为 vertical 或 horizontal。');
    end
end
