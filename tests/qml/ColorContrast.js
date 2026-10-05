.pragma library

// Actual rendered pairs, including state overlays, not just opaque palette roles.
function composite(foreground, background) {
    const alpha = foreground.a === undefined ? 1 : foreground.a;
    return {
        r: foreground.r * alpha + background.r * (1 - alpha),
        g: foreground.g * alpha + background.g * (1 - alpha),
        b: foreground.b * alpha + background.b * (1 - alpha),
        a: 1
    };
}
function luminance(color) {
    function linear(value) {
        return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
    }
    return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722;
}
function ratio(left, right) {
    const a = luminance(left), b = luminance(right);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
