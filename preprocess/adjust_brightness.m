function outImg = adjust_brightness(img, delta)
%ADJUST_BRIGHTNESS Add a brightness delta and clamp to the image range.

    if nargin < 2 || isempty(delta)
        delta = 0;
    elseif ~isnumeric(delta)
        delta = str2double(char(string(delta)));
    end

    if isnan(delta)
        error('adjust_brightness:InvalidDelta', '亮度参数应为数字，例如 30 或 -30。');
    end

    if isinteger(img)
        minVal = double(intmin(class(img)));
        maxVal = double(intmax(class(img)));
        values = double(img) + delta;
        values = min(max(values, minVal), maxVal);
        outImg = cast(values, class(img));
        return;
    end

    values = double(img) + delta;
    if max(double(img(:))) <= 1
        values = min(max(values, 0), 1);
    end
    outImg = cast(values, class(img));
end
