.pragma library

// Shared bounds and glyph thresholds for the bar and its OSDs.
function percent(value) {
    return Math.max(0, Math.min(100, Number(value) || 0));
}
function audioIcon(audio) {
    if (!audio || audio.muted || !audio.available)
        return "󰝟";
    const level = percent(audio.volume_percent);
    return level < 34 ? "" : level < 67 ? "" : "";
}
function powerProfileIcon(profile) {
    const value = profile && profile.profile ? profile.profile : "";
    return value === "power-saver" ? "" : value === "balanced" ? "" : "";
}
