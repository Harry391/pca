function batchResult = run_batch_test(model, testDir, options)
%RUN_BATCH_TEST Placeholder batch evaluation contract.

    %#ok<INUSD>
    batchResult = struct('status', 'todo', 'message', 'run_batch_test not implemented', ...
        'accuracy', [], 'totalElapsedMs', [], 'avgElapsedMs', [], ...
        'perImageResults', [], 'confusionSummary', []);
end

