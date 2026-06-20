function initialize_empty_axes(ax, titleText, theme)
%INITIALIZE_EMPTY_AXES Keep a display axes blank until real image data appears.

    if nargin < 3 || isempty(theme)
        theme = get_ui_theme();
    end
    if isempty(ax) || ~isvalid(ax)
        return;
    end

    cla(ax);
    ax.Color = theme.colors.cream;
    ax.Box = 'on';
    ax.XColor = [0.72 0.72 0.72];
    ax.YColor = [0.72 0.72 0.72];
    ax.XTick = [];
    ax.YTick = [];
    axis(ax, 'ij');
    if nargin >= 2 && ~isempty(titleText)
        title(ax, titleText, 'FontName', theme.fonts.body, 'FontWeight', 'bold');
    end
end
