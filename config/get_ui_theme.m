function theme = get_ui_theme()
%GET_UI_THEME Central cute hand-drawn GUI theme.

    theme = struct();

    theme.colors = struct();
    theme.colors.mistBlue = [217 238 242] ./ 255;
    theme.colors.skyBlue = [168 218 242] ./ 255;
    theme.colors.paleSkyBlue = [209 238 249] ./ 255;
    theme.colors.mintGreen = [217 245 200] ./ 255;
    theme.colors.sakuraPink = [247 200 216] ./ 255;
    theme.colors.cream = [255 253 247] ./ 255;
    theme.colors.brightBlue = [53 174 234] ./ 255;
    theme.colors.freshGreen = [139 195 74] ./ 255;
    theme.colors.buttonGreen = [185 232 161] ./ 255;
    theme.colors.buttonBlue = [142 205 235] ./ 255;
    theme.colors.coralRed = [239 91 91] ./ 255;
    theme.colors.softYellow = [249 239 165] ./ 255;
    theme.colors.softLavender = [241 229 244] ./ 255;
    theme.colors.ink = [43 55 61] ./ 255;
    theme.colors.mutedInk = [92 108 115] ./ 255;
    theme.colors.border = [129 183 195] ./ 255;
    theme.colors.panelLine = [162 185 174] ./ 255;

    theme.fonts = struct();
    theme.fonts.title = 'Microsoft YaHei UI';
    theme.fonts.body = 'Microsoft YaHei UI';
    theme.fonts.english = 'Comic Sans MS';

    theme.sizes = struct();
    theme.sizes.title = 25;
    theme.sizes.sectionTitle = 18;
    theme.sizes.body = 12;
    theme.sizes.small = 10;

    theme.layout = struct();
    theme.layout.windowPosition = [80 60 1480 860];
    theme.layout.columnWidth = {'25x', '45x', '30x'};
    theme.layout.padding = [12 12 12 12];
    theme.layout.spacing = 10;
end
