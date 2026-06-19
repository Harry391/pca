function outDir = run_matlab_align_from_auto_points(pointsCsv, outDir, maxImages, overwrite)
%RUN_MATLAB_ALIGN_FROM_AUTO_POINTS Align raw faces in MATLAB from external click points.
%
% The CSV only supplies click coordinates: left eye, right eye and mouth.
% All image preprocessing here is done by MATLAB.

    rootDir = fileparts(mfilename('fullpath'));
    addpath(genpath(rootDir));

    if nargin < 1 || isempty(pointsCsv)
        pointsCsv = fullfile(rootDir, 'data', 'auto_click_points', 'raw_face_points.csv');
    end
    if nargin < 2 || isempty(outDir)
        outDir = fullfile(rootDir, 'data', 'matlab_aligned_from_auto_points');
    end
    if nargin < 3 || isempty(maxImages)
        maxImages = inf;
    end
    if nargin < 4 || isempty(overwrite)
        overwrite = true;
    end

    if ~isfile(pointsCsv)
        error('Points CSV not found: %s', pointsCsv);
    end
    if ~isfolder(outDir)
        mkdir(outDir);
    end

    rows = read_points_csv(pointsCsv);
    if isfinite(maxImages)
        rows = rows(1:min(height(rows), maxImages), :);
    end

    manifestPath = fullfile(outDir, 'matlab_alignment_manifest.csv');
    fid = fopen(manifestPath, 'w', 'n', 'UTF-8');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'source_path,output_path,label,status,left_eye_x,left_eye_y,right_eye_x,right_eye_y,mouth_x,mouth_y\n');

    total = height(rows);
    savedCount = 0;
    skippedCount = 0;
    fprintf('MATLAB alignment from auto points\n');
    fprintf('Points CSV: %s\n', pointsCsv);
    fprintf('Output: %s\n', outDir);
    fprintf('Rows: %d\n', total);

    for i = 1:total
        sourcePath = char(rows.source_path(i));
        label = char(rows.label(i));
        status = char(rows.status(i));

        if ~strcmp(status, 'auto_points') || ~isfile(sourcePath)
            skippedCount = skippedCount + 1;
            fprintf(fid, '%s,%s,%s,%s,,,,,,\n', csv_escape(sourcePath), csv_escape(''), csv_escape(label), csv_escape(status));
            fprintf('%04d/%04d skipped: %s | %s\n', i, total, label, status);
            continue;
        end

        [~, stem, sourceExt] = fileparts(sourcePath);
        personDir = fullfile(outDir, label);
        if ~isfolder(personDir)
            mkdir(personDir);
        end

        if strcmpi(sourceExt, '.png')
            outputPath = fullfile(personDir, sprintf('%s_matlab_aligned.png', stem));
        else
            outputPath = fullfile(personDir, sprintf('%s_matlab_aligned.jpg', stem));
        end

        if isfile(outputPath) && ~overwrite
            savedCount = savedCount + 1;
            fprintf('%04d/%04d exists: %s\n', i, total, outputPath);
            continue;
        end

        points = [
            rows.left_eye_x(i), rows.left_eye_y(i);
            rows.right_eye_x(i), rows.right_eye_y(i);
            rows.mouth_x(i), rows.mouth_y(i)
        ];

        img = imread(sourcePath);
        alignInfo = align_face_from_points(img, points, [112, 92]);
        imwrite(im2uint8(alignInfo.alignedFace), outputPath);

        fprintf(fid, '%s,%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n', ...
            csv_escape(sourcePath), csv_escape(outputPath), csv_escape(label), csv_escape('matlab_aligned'), ...
            points(1, 1), points(1, 2), points(2, 1), points(2, 2), points(3, 1), points(3, 2));
        savedCount = savedCount + 1;
        fprintf('%04d/%04d saved: %s\n', i, total, outputPath);
    end

    clear cleanup;
    fprintf('MATLAB aligned images: %d\n', savedCount);
    fprintf('Skipped rows: %d\n', skippedCount);
    fprintf('Output: %s\n', outDir);
    fprintf('Manifest: %s\n', manifestPath);
end

function rows = read_points_csv(pointsCsv)
    try
        rows = readtable(pointsCsv, 'TextType', 'string', 'Encoding', 'UTF-8');
    catch
        rows = readtable(pointsCsv, 'TextType', 'string');
    end

    requiredNames = ["source_path", "label", "status", "left_eye_x", "left_eye_y", "right_eye_x", "right_eye_y", "mouth_x", "mouth_y"];
    names = string(rows.Properties.VariableNames);
    missing = setdiff(requiredNames, names);
    if ~isempty(missing)
        error('Points CSV missing columns: %s', strjoin(missing, ', '));
    end
end

function text = csv_escape(value)
    text = char(value);
    text = strrep(text, '"', '""');
    text = ['"', text, '"'];
end
