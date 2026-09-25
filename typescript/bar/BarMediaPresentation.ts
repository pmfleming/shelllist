interface MediaPlayer {
    id?: string;
    desktop_entry?: string;
    playback_status?: string;
    length_us?: number;
    position_us?: number;
    position_observed_at_unix_ms?: number;
    playback_rate?: number;
}
interface MediaState {
    players?: MediaPlayer[];
    active_player?: string;
}
type Maybe<T> = T | null | undefined;

function clamp(value: unknown, minimum: number, maximum: number) {
    return Math.max(minimum, Math.min(maximum, Number(value) || 0));
}

function playerFor(media: Maybe<MediaState>) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    return players.find(function (player: MediaPlayer) { return player.id === media!.active_player; }) || null;
}

function mediaPlayerOrdinal(media: Maybe<MediaState>, playerId: Maybe<string>) {
    const players = media && Array.isArray(media.players) ? media.players : [];
    const index = players.findIndex(function (player: MediaPlayer) { return player.id === playerId; });
    return index < 0 ? "" : (index + 1) + "/" + players.length;
}

function playerIcon(player: Maybe<MediaPlayer>) {
    return player && String(player.desktop_entry || "").toLowerCase().indexOf("spotify") >= 0 ? "" : "";
}

function playPauseActionIcon(player: Maybe<MediaPlayer>) {
    const status = player ? String(player.playback_status || "").toLowerCase() : "stopped";
    return status === "playing" ? "" : "";
}

function mediaPositionPercent(player: Maybe<MediaPlayer>, nowMs: unknown) {
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
