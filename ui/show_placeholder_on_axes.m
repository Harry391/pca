function show_placeholder_on_axes(ax, imagePath, titleText)
%SHOW_PLACEHOLDER_ON_AXES Display a cute empty-state image in an axes.

    if isempty(ax) || ~isvalid(ax) || ~exist(imagePath, 'file')
        return;
    end

    img = imread(imagePath);
    imshow(img, 'Parent', ax);
    axis(ax, 'image');
    ax.Color = [255 253 247] ./ 255;
    ax.Box = 'off';
    ax.XTick = [];
    ax.YTick = [];
    if nargin >= 3 && ~isempty(titleText)
        title(ax, titleText);
    end
end
