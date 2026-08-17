.pragma library

function screenSignature(screens) {
    const values = [];
    for (let index = 0; index < (screens || []).length; index++) {
        const screen = screens[index];
        if (!screen || !screen.name)
            continue;
        values.push(screen.name + ":" + Number(screen.width || 0) + "x" + Number(screen.height || 0));
    }
    return values.sort().join("|");
}

function heartbeatIndicatesResume(previousMs, currentMs, intervalMs, toleranceMs) {
    const previous = Number(previousMs) || 0;
    const current = Number(currentMs) || 0;
    if (previous <= 0 || current <= previous)
        return false;
    return current - previous > Number(intervalMs) + Number(toleranceMs);
}
