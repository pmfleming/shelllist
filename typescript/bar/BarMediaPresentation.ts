interface MediaPlayer {
    id?: string;
    playback_status?: string;
    control_mode?: string;
    content_type?: string;
    can_control?: boolean;
    can_play?: boolean;
    can_pause?: boolean;
    can_seek?: boolean;
    can_next?: boolean;
    can_previous?: boolean;
}
interface MediaState { players?: MediaPlayer[]; active_player?: string }
type Maybe<T> = T | null | undefined;
function playerFor(media: Maybe<MediaState>) {
    return (media?.players || []).find(player => player.id === media?.active_player) || null;
}
function trackControls(player: Maybe<MediaPlayer>) {
    return !!player && (player.control_mode === "tracks" || ((!player.control_mode || player.control_mode === "automatic") && player.content_type === "music"));
}
function transportAction(player: Maybe<MediaPlayer>, forward: boolean) {
    const tracks = trackControls(player);
    return {
        operation: tracks ? (forward ? "next" : "previous") : "seek",
        offset: forward ? 30 : -30,
        icon: tracks ? (forward ? "" : "") : (forward ? "forward_30" : "replay_30"),
        label: tracks ? (forward ? "Next track" : "Previous track") : (forward ? "Fast-forward 30 seconds" : "Rewind 30 seconds"),
        enabled: !!player && !!player.can_control && (tracks ? !!(forward ? player.can_next : player.can_previous) : !!player.can_seek)
    };
}
function canPlayPause(player: Maybe<MediaPlayer>) {
    return !!player && !!player.can_control && (String(player.playback_status || "").toLowerCase() === "playing" ? !!player.can_pause : !!player.can_play);
}
function playPauseActionIcon(player: Maybe<MediaPlayer>) {
    return String(player?.playback_status || "").toLowerCase() === "playing" ? "" : "";
}
