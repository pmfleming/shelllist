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
    const direction = forward ? 1 : 0;
    return {
        operation: tracks ? ["previous", "next"][direction] : "seek",
        offset: [-30, 30][direction],
        icon: (tracks ? ["", ""] : ["replay_30", "forward_30"])[direction],
        label: (tracks ? ["Previous track", "Next track"] : ["Rewind 30 seconds", "Fast-forward 30 seconds"])[direction],
        enabled: !!player?.can_control && !!(tracks ? [player.can_previous, player.can_next][direction] : player?.can_seek)
    };
}
function canPlayPause(player: Maybe<MediaPlayer>) {
    return !!player && !!player.can_control && (String(player.playback_status || "").toLowerCase() === "playing" ? !!player.can_pause : !!player.can_play);
}
function playPauseActionIcon(player: Maybe<MediaPlayer>) {
    return String(player?.playback_status || "").toLowerCase() === "playing" ? "" : "";
}
