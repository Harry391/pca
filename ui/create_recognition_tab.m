function handles = create_recognition_tab(parentTab)
%CREATE_RECOGNITION_TAB Build recognition tab shell.

    handles = struct();
    handles.Parent = parentTab;
    handles.PlaceholderLabel = uilabel(parentTab, ...
        'Text', 'Recognition tab scaffold initialized.', ...
        'Position', [30 740 280 22]);
end

