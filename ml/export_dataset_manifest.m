function manifest = export_dataset_manifest(dataDir, trainDir, testDir, classSizeInfo)
%EXPORT_DATASET_MANIFEST Placeholder dataset manifest contract.

    manifest = struct('status', 'todo', 'totalRawCount', 0, 'expectedRawCount', 0, ...
        'trainCount', 0, 'testCount', 0, 'splitRatio', [], 'perClassSummary', [], ...
        'dataDir', dataDir, 'trainDir', trainDir, 'testDir', testDir, 'classSizeInfo', classSizeInfo);
end

