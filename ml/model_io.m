function out = model_io(action, payload, filePath)
%MODEL_IO Save or load hand-written PCA/SVM model structs.

    if nargin < 3 || isempty(filePath)
        filePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'models', 'pca_svm_model.mat');
    end

    out = struct('status', 'error', 'message', '', 'action', action, 'filePath', filePath, 'model', []);
    action = lower(char(action));

    switch action
        case 'save'
            model = payload; %#ok<NASGU>
            targetDir = fileparts(filePath);
            if ~isfolder(targetDir)
                mkdir(targetDir);
            end
            save(filePath, 'model');
            out.status = 'ok';
            out.message = 'model saved';
            out.model = model;

        case 'load'
            if ~isfile(filePath)
                out.message = ['model file does not exist: ', filePath];
                return;
            end
            data = load(filePath, 'model');
            if ~isfield(data, 'model')
                out.message = 'file does not contain variable named model';
                return;
            end
            out.status = 'ok';
            out.message = 'model loaded';
            out.model = data.model;

        otherwise
            out.message = ['unsupported model_io action: ', action];
    end
end
