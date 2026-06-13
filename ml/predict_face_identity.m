function result = predict_face_identity(model, imageData, options)
%PREDICT_FACE_IDENTITY Hand-written PCA/SVM single prediction contract.

    %#ok<INUSD>
    result = struct('status', 'todo', 'message', 'hand-written predict_face_identity not implemented', ...
        'name', '', 'topKNames', {{}}, 'topKScores', [], 'faceBox', [], ...
        'alignedFace', [], 'elapsedMs', []);
end
