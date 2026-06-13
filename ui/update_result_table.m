function update_result_table(tableHandle, data)
%UPDATE_RESULT_TABLE Refresh a UI table with batch results.

    if isempty(tableHandle) || ~isvalid(tableHandle)
        return;
    end
    tableHandle.Data = data;
end

