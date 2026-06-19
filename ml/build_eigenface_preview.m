function eigenfaceImgs = build_eigenface_preview(model, k)
%BUILD_EIGENFACE_PREVIEW Eigenface preview contract for hand-written PCA.

    if nargin < 2 || isempty(k)
        k = 8;
    end

    if ~isfield(model, 'eigenfaces') || isempty(model.eigenfaces)
        eigenfaceImgs = cell(1, k);
        return;
    end

    count = min(k, size(model.eigenfaces, 2));
    eigenfaceImgs = cell(1, count);
    for i = 1:count
        img = reshape(model.eigenfaces(:, i), model.imageSize(1), model.imageSize(2));
        img = img - min(img(:));
        rangeValue = max(img(:));
        if rangeValue > 0
            img = img / rangeValue;
        end
        eigenfaceImgs{i} = img;
    end
end
