.pragma library

// Only view geometry lives here. bar-daemon supplies resolved logical insets;
// QScreen remains authoritative for logical size and fractional scaling.
function rectangle(screen, margins) {
    if (!margins)
        return null;
    const left = Math.max(0, Math.min(screen.width - 1, Math.round(margins.left)));
    const top = Math.max(0, Math.min(screen.height - 1, Math.round(margins.top)));
    const right = Math.max(0, Math.min(screen.width - left - 1, Math.round(margins.right)));
    const bottom = Math.max(0, Math.min(screen.height - top - 1, Math.round(margins.bottom)));
    return {
        x: screen.x + left,
        y: screen.y + top,
        width: screen.width - left - right,
        height: screen.height - top - bottom,
        left: left,
        top: top,
        right: right,
        bottom: bottom
    };
}
