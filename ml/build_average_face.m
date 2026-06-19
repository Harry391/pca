function avgFace = build_average_face(model)
%BUILD_AVERAGE_FACE Average face contract for hand-written PCA pipeline.

    if isfield(model, 'meanFace') && ~isempty(model.meanFace)
        avgFace = model.meanFace;
    elseif isfield(model, 'meanVector') && isfield(model, 'imageSize')
        avgFace = reshape(model.meanVector, model.imageSize(1), model.imageSize(2));
    else
        avgFace = [];
    end
end
