function handles = create_preprocess_tab(parentTab)
%CREATE_PREPROCESS_TAB Build preprocess tab shell.

    handles = struct();
    handles.Parent = parentTab;
    handles.PlaceholderLabel = uilabel(parentTab, ...
        'Text', 'Preprocess tab scaffold initialized.', ...
        'Position', [30 740 260 22]);
end

