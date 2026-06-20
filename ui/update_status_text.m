function update_status_text(textHandle, messageLines)
%UPDATE_STATUS_TEXT Refresh a status label or text area.

    if isempty(textHandle) || ~isvalid(textHandle)
        return;
    end
    if isprop(textHandle, 'Value')
        textHandle.Value = messageLines;
    elseif isprop(textHandle, 'Text')
        if iscell(messageLines)
            textHandle.Text = strjoin(string(messageLines), newline);
        else
            textHandle.Text = char(messageLines);
        end
    end
end

