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

function resumeGenerationAdvanced(previous, current) {
    // Initial subscription and daemon restart establish a baseline. A generation
    // is durable snapshot state, so coalesced PrepareForSleep edges aren't lost.
    return Number.isFinite(previous) && Number.isFinite(current) && previous >= 0 && current > previous;
}
