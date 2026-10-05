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
    const direction = forward ? 1 : 0;
    return {
        operation: tracks ? ["previous", "next"][direction] : "seek",
        offset: [-30, 30][direction],
        icon: (tracks ? ["", ""] : ["replay_30", "forward_30"])[direction],
        label: (tracks ? ["Previous track", "Next track"] : ["Rewind 30 seconds", "Fast-forward 30 seconds"])[direction],
        enabled: !!player?.can_control && !!(tracks ? [player.can_previous, player.can_next][direction] : player?.can_seek)
    };
}
function canPlayPause(player) {
    return !!player && !!player.can_control && (String(player.playback_status || "").toLowerCase() === "playing" ? !!player.can_pause : !!player.can_play);
}
function playPauseActionIcon(player) {
    return String(player?.playback_status || "").toLowerCase() === "playing" ? "" : "";
}
