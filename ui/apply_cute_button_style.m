function apply_cute_button_style(buttonHandle, theme, variant)
%APPLY_CUTE_BUTTON_STYLE Apply the shared rounded pastel button style.

    if nargin < 2 || isempty(theme)
        theme = get_ui_theme();
    end
    if nargin < 3 || isempty(variant)
        variant = "primary";
    end

    switch string(variant)
        case "pink"
            bg = theme.colors.sakuraPink;
        case "blue"
            bg = theme.colors.buttonBlue;
        case "green"
            bg = theme.colors.buttonGreen;
        case "danger"
            bg = [1.0 0.78 0.78];
        otherwise
            bg = theme.colors.softYellow;
    end

    if isempty(buttonHandle) || ~isvalid(buttonHandle)
        return;
    end

    buttonHandle.BackgroundColor = bg;
    buttonHandle.FontColor = theme.colors.ink;
    buttonHandle.FontName = theme.fonts.body;
    buttonHandle.FontWeight = 'bold';
end
