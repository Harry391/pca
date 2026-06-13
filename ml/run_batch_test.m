function batchResult = run_batch_test(model, testDir, options)
%RUN_BATCH_TEST Hand-written PCA/SVM batch evaluation contract.

    %#ok<INUSD>
    batchResult = struct('status', 'todo', 'message', 'hand-written run_batch_test not implemented', ...
        'accuracy', [], 'totalElapsedMs', [], 'avgElapsedMs', [], ...
        'perImageResults', [], 'confusionSummary', []);
end
