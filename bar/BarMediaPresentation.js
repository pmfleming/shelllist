.pragma library

"use strict";
function playerFor(media) {
    return (media?.players || []).find(player => player.id === media?.active_player) || null;
}
function trackControls(player) {
    return !!player && (player.control_mode === "tracks" || ((!player.control_mode || player.control_mode === "automatic") && player.content_type === "music"));
}
function transportAction(player, forward) {
    const tracks = trackControls(player);
    return {
        operation: tracks ? (forward ? "next" : "previous") : "seek",
        offset: forward ? 30 : -30,
        icon: tracks ? (forward ? "" : "") : (forward ? "forward_30" : "replay_30"),
        label: tracks ? (forward ? "Next track" : "Previous track") : (forward ? "Fast-forward 30 seconds" : "Rewind 30 seconds"),
        enabled: !!player && !!player.can_control && (tracks ? !!(forward ? player.can_next : player.can_previous) : !!player.can_seek)
    };
}
function canPlayPause(player) {
    return !!player && !!player.can_control && (String(player.playback_status || "").toLowerCase() === "playing" ? !!player.can_pause : !!player.can_play);
}
function playPauseActionIcon(player) {
    return String(player?.playback_status || "").toLowerCase() === "playing" ? "" : "";
}
