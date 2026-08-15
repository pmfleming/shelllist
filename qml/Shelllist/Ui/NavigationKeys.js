function listDirection(text, modifiers, noModifier, shiftModifier) {
    if (modifiers !== noModifier && modifiers !== shiftModifier)
        return 0;
    const key = String(text || "").toLowerCase();
    if (key === "j")
        return 1;
    if (key === "k")
        return -1;
    return 0;
}

if (typeof module !== "undefined")
    module.exports = { listDirection: listDirection };
