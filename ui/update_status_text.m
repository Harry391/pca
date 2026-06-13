function update_status_text(textHandle, messageLines)
%UPDATE_STATUS_TEXT Refresh a status label or text area.

    if isempty(textHandle) || ~isvalid(textHandle)
        return;
    end
    textHandle.Value = messageLines;
end

