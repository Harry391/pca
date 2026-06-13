function update_axes_image(ax, img, titleText)
%UPDATE_AXES_IMAGE Display an image on a UIAxes.

    if isempty(ax) || ~isvalid(ax)
        return;
    end
    imshow(img, 'Parent', ax);
    if nargin >= 3 && ~isempty(titleText)
        title(ax, titleText);
    end
end

