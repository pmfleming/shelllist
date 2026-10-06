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
// Presentation only. Never infer a service from a title, artwork/CDN URL or a
// substring match; the daemon's explicit isolated-browser labels count as identity.
function serviceFor(player) {
    const desktop = String(player?.desktop_entry || "").trim().toLowerCase().replace(/\.desktop$/, "");
    const identity = String(player?.identity || "").trim().toLowerCase();
    const services = [
        { key: "spotify", name: "Spotify", desktops: ["spotify", "spotify-client", "com.spotify.client"], identities: ["spotify"], icons: ["spotify-client", "spotify", "com.spotify.Client"] },
        { key: "pocketcasts", name: "Pocket Casts", desktops: ["com.laufan.pocketcasts", "pocketcasts", "pocket-casts", "com.pocketcasts.pocketcasts"], identities: ["pocket casts", "pocketcasts"], icons: ["com.laufan.pocketcasts", "pocketcasts", "pocket-casts"] },
        { key: "audible", name: "Audible", desktops: ["com.laufan.audible", "audible"], identities: ["audible"], icons: ["com.laufan.audible", "audible"] }
    ];
    return services.find(service => service.desktops.includes(desktop))
        || services.find(service => service.identities.includes(identity)) || null;
}
function contentKind(player) {
    const kind = String(player?.content_type || "unknown").toLowerCase();
    if (["music", "podcast", "audiobook", "video"].includes(kind))
        return kind;
    const service = serviceFor(player);
    return service?.key === "pocketcasts" ? "podcast" : service?.key === "audible" ? "audiobook" : "unknown";
}
function contentIcon(player) {
    const kind = contentKind(player);
    return kind === "podcast" ? "headphones" : kind === "audiobook" ? "auto_stories" : kind === "video" ? "videocam" : "music_note";
}
function distinctLabels(values) {
    const seen = [];
    return values.map(value => String(value || "").trim()).filter(value => {
        const key = value.toLowerCase();
        if (!key || seen.includes(key))
            return false;
        seen.push(key);
        return true;
    }).join(" · ");
}
function identityLabel(player) {
    const service = serviceFor(player);
    const browser = /^org\.mpris\.MediaPlayer2\.chrom(?:e|ium)\.instance\d+$/.test(player?.id || "") ? "Chrome" : "";
    return service ? distinctLabels([service.name, browser ? "via " + browser : ""])
        : String(player?.identity || "");
}
function heading(player) {
    const kind = contentKind(player);
    const context = kind === "podcast" ? player?.album || player?.artist
        : kind === "music" ? player?.artist : kind === "audiobook" ? player?.album : "";
    return String(context || player?.title || serviceFor(player)?.name || player?.identity || "");
}
function subtitle(player) {
    const title = String(player?.title || "").trim().toLowerCase();
    return distinctLabels([player?.artist, player?.album].filter(value => String(value || "").trim().toLowerCase() !== title));
}
function stateIcon(player) {
    const status = String(player?.playback_status || "").toLowerCase();
    return status === "playing" ? "equalizer" : status === "paused" ? "pause" : "stop";
}
function actionGroup(player, id) {
    if (id === "play-pause")
        return "primary";
    return (trackControls(player) ? ["previous", "next"] : ["rewind", "forward"]).includes(id) ? "toolbar" : "overflow";
}
function durationText(microseconds) {
    const seconds = Math.max(0, Math.floor(microseconds / 1000000));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds / 60) % 60;
    const two = (value) => String(value).padStart(2, "0");
    return (hours ? hours + ":" + two(minutes) : String(minutes)) + ":" + two(seconds % 60);
}
function timeline(player, nowMs) {
    const length = player?.length_us;
    const position = player?.position_us;
    const rate = player?.playback_rate;
    const hasRate = typeof rate === "number" && Number.isFinite(rate) && rate > 0;
    const known = typeof length === "number" && Number.isFinite(length) && length > 0
        && typeof position === "number" && Number.isFinite(position) && position >= 0;
    const speed = hasRate ? String(Math.round(rate * 100) / 100) + "×" : "";
    if (!known)
        return { known: false, fraction: 0, elapsed: "—:—", remaining: "—:—", speed };
    const observed = player?.position_observed_at_unix_ms;
    // The daemon samples every two seconds. Freeze a stale/disconnected snapshot
    // after five seconds; never extrapolate indefinitely or mutate daemon state.
    const age = typeof observed === "number" && Number.isFinite(observed) && observed > 0
        && Number.isFinite(nowMs) ? Math.max(0, Math.min(5000, nowMs - observed)) : 0;
    const advance = String(player?.playback_status || "").toLowerCase() === "playing" && hasRate ? age * 1000 * rate : 0;
    const current = Math.min(length, position + advance);
    return { known: true, fraction: current / length, elapsed: durationText(current), remaining: "−" + durationText(length - current), speed };
}
