function counts = draw_histogram(img, ax)
%DRAW_HISTOGRAM Draw grayscale histogram.

    grayImg = convert_to_gray(img);
    counts = imhist(grayImg);
    if nargin >= 2 && ~isempty(ax) && isvalid(ax)
        bar(ax, 0:255, counts);
        xlim(ax, [0, 255]);
    end
end

