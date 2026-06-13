function stats = compute_image_stats(img)
%COMPUTE_IMAGE_STATS Basic image statistics for GUI display.

    temp = double(img(:));
    stats = struct();
    stats.maxVal = max(temp);
    stats.minVal = min(temp);
    stats.meanVal = mean(temp);
    stats.varVal = var(temp, 1);
end

