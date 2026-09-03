.pragma library

"use strict";
function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}
function playerFor(media) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    return players.find(function (player) { return player.id === media.active_player; }) || null;
}
function mediaPlayerOrdinal(media, playerId) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    const index = players.findIndex(function (player) { return player.id === playerId; });
    return index < 0 ? "" : (index + 1) + "/" + players.length;
}
function playerIcon(player) {
    return player && String(player.desktop_entry || "").toLowerCase().indexOf("spotify") >= 0 ? "" : "";
}
function playbackIcon(player) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : status === "paused" ? "" : "";
}
function playPauseActionIcon(player) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : "";
}
function mediaText(player) {
    if (!player)
        return "";
    const title = player.title || player.identity || "Unknown track";
    return playerIcon(player) + " " + title + "  " + playbackIcon(player);
}
function mediaPositionPercent(player, nowMs) {
    if (!player)
        return 0;
    const length = Math.max(0, Number(player.length_us) || 0);
    if (length <= 0)
        return 0;
    let position = Math.max(0, Number(player.position_us) || 0);
    const status = String(player.playback_status || "").toLowerCase();
    if (status === "playing") {
        const observedAt = Math.max(0, Number(player.position_observed_at_unix_ms) || 0);
        const elapsedMs = Math.max(0, (Number(nowMs) || 0) - observedAt);
        const rate = Math.max(0, Number(player.playback_rate) || 1);
        position += elapsedMs * 1000 * rate;
    }
    return clamp(position / length * 100, 0, 100);
}
