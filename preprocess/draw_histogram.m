function counts = draw_histogram(img, ax)
%DRAW_HISTOGRAM Draw grayscale histogram.

    grayImg = convert_to_gray(img);
    if isfloat(grayImg) && max(grayImg(:)) > 1
        grayImg = uint8(min(max(grayImg, 0), 255));
    end

    counts = imhist(grayImg);
    if nargin >= 2 && ~isempty(ax) && isvalid(ax)
        bar(ax, 0:255, counts, 'BarWidth', 1);
        xlim(ax, [0, 255]);
        xlabel(ax, '灰度值（0=黑，255=白）');
        ylabel(ax, '像素数量');
        grid(ax, 'on');

        nonZeroCounts = counts(counts > 0);
        if ~isempty(nonZeroCounts)
            ymax = max(nonZeroCounts);
            ymin = min(nonZeroCounts);
            if ymax > 50 * max(ymin, 1)
                ax.YScale = 'log';
                ylabel(ax, '像素数量（对数显示）');
                ylim(ax, [1, max(2, ymax * 1.2)]);
            else
                ylim(ax, [0, ymax * 1.1]);
            end
        end
    end
end

