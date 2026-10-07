interface MediaPlayer {
    id?: string;
    identity?: string;
    desktop_entry?: string;
    source?: {url?: string; service?: string | null} | null;
    title?: string;
    artist?: string;
    album?: string;
    length_us?: number;
    position_us?: number;
    position_observed_at_unix_ms?: number;
    playback_rate?: number;
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

// Presentation only. Never infer a service from a title, artwork/CDN URL or a
// substring match. The daemon owns source URL recognition; older snapshots still
// use exact application identities and explicit isolated-browser labels.
function serviceFor(player: Maybe<MediaPlayer>) {
    const desktop = String(player?.desktop_entry || "").trim().toLowerCase().replace(/\.desktop$/, "");
    const identity = String(player?.identity || "").trim().toLowerCase();
    const services = [
        {key: "spotify", name: "Spotify", desktops: ["spotify", "spotify-client", "com.spotify.client"], identities: ["spotify"], icons: ["spotify-client", "spotify", "com.spotify.Client"]},
        {key: "pocketcasts", name: "Pocket Casts", desktops: ["com.laufan.pocketcasts", "pocketcasts", "pocket-casts", "com.pocketcasts.pocketcasts"], identities: ["pocket casts", "pocketcasts"], icons: ["com.laufan.pocketcasts", "pocketcasts", "pocket-casts"]},
        {key: "audible", name: "Audible", desktops: ["com.laufan.audible", "audible"], identities: ["audible"], icons: ["com.laufan.audible", "audible"]},
        {key: "youtube", name: "YouTube", desktops: [], identities: [], icons: ["youtube"]},
        {key: "vimeo", name: "Vimeo", desktops: [], identities: [], icons: ["vimeo"]},
        {key: "soundcloud", name: "SoundCloud", desktops: [], identities: [], icons: ["soundcloud"]}
    ];
    return services.find(service => service.key === player?.source?.service)
        || services.find(service => service.desktops.includes(desktop))
        || services.find(service => service.identities.includes(identity)) || null;
}
function contentKind(player: Maybe<MediaPlayer>) {
    const kind = String(player?.content_type || "unknown").toLowerCase();
    if (["music", "podcast", "audiobook", "video"].includes(kind)) return kind;
    // A recognized web service is not evidence of the current content kind.
    // Retain the historical isolated-app fallback only for source-less snapshots.
    if (player?.source) return "unknown";
    const service = serviceFor(player);
    return service?.key === "pocketcasts" ? "podcast" : service?.key === "audible" ? "audiobook" : "unknown";
}
function contentIcon(player: Maybe<MediaPlayer>) {
    const kind = contentKind(player);
    return kind === "podcast" ? "headphones" : kind === "audiobook" ? "auto_stories" : kind === "video" ? "videocam" : "music_note";
}
function distinctLabels(values: Maybe<string>[]) {
    const seen: string[] = [];
    return values.map(value => String(value || "").trim()).filter(value => {
        const key = value.toLowerCase();
        if (!key || seen.includes(key)) return false;
        seen.push(key);
        return true;
    }).join(" · ");
}
function identityLabel(player: Maybe<MediaPlayer>) {
    const service = serviceFor(player);
    const desktop = String(player?.desktop_entry || "").toLowerCase().replace(/\.desktop$/, "");
    const identity = String(player?.identity || "");
    const browsers = [
        {name: "Zen", desktops: ["zen", "zen-browser", "app.zen_browser.zen"], identities: ["zen", "mozilla zen", "zen browser"]},
        {name: "Firefox", desktops: ["firefox", "org.mozilla.firefox"], identities: ["firefox", "mozilla firefox"]},
        {name: "Chromium", desktops: ["chromium", "chromium-browser"], identities: ["chromium"]},
        {name: "Chrome", desktops: ["google-chrome", "google-chrome-stable"], identities: ["chrome", "google chrome"]}
    ];
    const browser = browsers.find(browser => browser.desktops.includes(desktop))
        || browsers.find(browser => browser.identities.includes(identity.toLowerCase()));
    const origin = browser?.name || (/^org\.mpris\.MediaPlayer2\.chrom(?:e|ium)\.instance\d+$/.test(player?.id || "") ? "Chrome"
        : player?.source?.service && identity.toLowerCase() !== service?.name.toLowerCase() ? identity : "");
    return service ? distinctLabels([service.name, origin ? "via " + origin : ""])
        : identity;
}
function heading(player: Maybe<MediaPlayer>) {
    const kind = contentKind(player);
    const context = kind === "podcast" ? player?.album || player?.artist
        : kind === "music" || kind === "video" ? player?.artist : kind === "audiobook" ? player?.album : "";
    // Video titles remain fully readable in the card, not duplicated/elided in
    // the header. A missing channel falls back to service/browser identity.
    const fallback = kind === "video" ? serviceFor(player)?.name || player?.identity || player?.title
        : player?.title || serviceFor(player)?.name || player?.identity;
    return String(context || fallback || "");
}
function subtitle(player: Maybe<MediaPlayer>) {
    const title = String(player?.title || "").trim().toLowerCase();
    return distinctLabels([player?.artist, player?.album].filter(value => String(value || "").trim().toLowerCase() !== title));
}
function stateIcon(player: Maybe<MediaPlayer>) {
    const status = String(player?.playback_status || "").toLowerCase();
    return status === "playing" ? "equalizer" : status === "paused" ? "pause" : "stop";
}
function actionGroup(player: Maybe<MediaPlayer>, id: string) {
    if (id === "play-pause") return "primary";
    return "toolbar";
}
function durationText(microseconds: number) {
    const seconds = Math.max(0, Math.floor(microseconds / 1000000));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds / 60) % 60;
    const two = (value: number) => String(value).padStart(2, "0");
    return (hours ? hours + ":" + two(minutes) : String(minutes)) + ":" + two(seconds % 60);
}
function timeline(player: Maybe<MediaPlayer>, nowMs: number) {
    const length = player?.length_us;
    const position = player?.position_us;
    const rate = player?.playback_rate;
    const hasRate = typeof rate === "number" && Number.isFinite(rate) && rate > 0;
    const known = typeof length === "number" && Number.isFinite(length) && length > 0
        && typeof position === "number" && Number.isFinite(position) && position >= 0;
    const speed = hasRate ? String(Math.round(rate * 100) / 100) + "×" : "";
    if (!known) return {known: false, fraction: 0, elapsed: "—:—", remaining: "—:—", speed};
    const observed = player?.position_observed_at_unix_ms;
    // The daemon samples every two seconds. Freeze a stale/disconnected snapshot
    // after five seconds; never extrapolate indefinitely or mutate daemon state.
    const age = typeof observed === "number" && Number.isFinite(observed) && observed > 0
        && Number.isFinite(nowMs) ? Math.max(0, Math.min(5000, nowMs - observed)) : 0;
    const advance = String(player?.playback_status || "").toLowerCase() === "playing" && hasRate ? age * 1000 * rate : 0;
    const current = Math.min(length, position + advance);
    return {known: true, fraction: current / length, elapsed: durationText(current), remaining: "−" + durationText(length - current), speed};
}
