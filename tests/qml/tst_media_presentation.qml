import QtQuick
import QtTest
import "../../bar/BarMediaPresentation.js" as Media

TestCase {
    name: "MediaPresentation"
    function test_identity_data() {
        return [
            {tag: "desktop-alias", player: {desktop_entry: "com.spotify.Client", identity: "Spotify", content_type: "podcast", title: "Episode", album: "Show"}, service: "spotify", kind: "podcast", heading: "Show"},
            {tag: "isolated-pocketcasts", player: {desktop_entry: "com.laufan.pocketcasts", identity: "Chrome", title: "Episode", artist: "Show"}, service: "pocketcasts", kind: "podcast", heading: "Show"},
            {tag: "isolated-audible", player: {desktop_entry: "com.laufan.audible", identity: "Chrome", title: "The Rigor of Angels", artist: "Author"}, service: "audible", kind: "audiobook", heading: "The Rigor of Angels"},
            {tag: "book-context", player: {identity: "Audible", title: "Chapter 5", album: "The Rigor of Angels"}, service: "audible", kind: "audiobook", heading: "The Rigor of Angels"},
            {tag: "explicit-identity", player: {identity: "Pocket Casts", title: "Episode"}, service: "pocketcasts", kind: "podcast", heading: "Episode"},
            {tag: "spotify-unknown-not-music", player: {identity: "Spotify", title: "Unknown"}, service: "spotify", kind: "unknown", heading: "Unknown"},
            {tag: "no-title-inference", player: {identity: "Chrome", title: "The Anfield Wrap", album: "Pocket Casts", art_url: "https://audible.com/icon.png"}, service: "", kind: "unknown", heading: "The Anfield Wrap"},
            {tag: "no-substring-inference", player: {desktop_entry: "not-spotify", identity: "Spotify impostor", title: "Title"}, service: "", kind: "unknown", heading: "Title"},
            {tag: "music", player: {identity: "Spotify", content_type: "music", title: "Karma Police", artist: "Pierce The Veil"}, service: "spotify", kind: "music", heading: "Pierce The Veil"},
            {tag: "fallback", player: {identity: "Player"}, service: "", kind: "unknown", heading: "Player"},
            {tag: "youtube-source", player: {identity: "Mozilla zen", source: {service: "youtube"}, content_type: "video", title: "Video"}, service: "youtube", kind: "video", heading: "Video"},
            {tag: "vimeo-source", player: {identity: "Firefox", source: {service: "vimeo"}, content_type: "video", title: "Film"}, service: "vimeo", kind: "video", heading: "Film"},
            {tag: "soundcloud-not-necessarily-music", player: {identity: "Mozilla zen", source: {service: "soundcloud"}, title: "Recording"}, service: "soundcloud", kind: "unknown", heading: "Recording"},
            {tag: "audible-url-not-a-book", player: {identity: "Mozilla zen", source: {service: "audible"}, title: "Preview"}, service: "audible", kind: "unknown", heading: "Preview"},
            {tag: "pocketcasts-url-not-an-episode", player: {identity: "Mozilla zen", source: {service: "pocketcasts"}, title: "Page"}, service: "pocketcasts", kind: "unknown", heading: "Page"},
            {tag: "source-precedes-isolated-label", player: {identity: "Audible", source: {service: "vimeo"}, content_type: "video", title: "Film"}, service: "vimeo", kind: "video", heading: "Film"},
            {tag: "unknown-source", player: {identity: "Mozilla zen", source: {service: "future-service", url: "https://youtube.com/watch?v=example"}, title: "Video"}, service: "", kind: "unknown", heading: "Video"}
        ];
    }
    function test_identity(data) {
        const service = Media.serviceFor(data.player);
        compare(service ? service.key : "", data.service);
        compare(Media.contentKind(data.player), data.kind);
        compare(Media.heading(data.player), data.heading);
        compare(Media.trackControls(data.player), data.kind === "music");
        compare(Media.actionGroup(data.player, "play-pause"), "primary");
    }
    function test_labelsAndOverrides() {
        compare(Media.subtitle({title: "Title", album: "Show", artist: "show"}), "show");
        compare(Media.subtitle({title: "Title", album: "Title", artist: "Artist"}), "Artist");
        compare(Media.stateIcon({playback_status: "Playing"}), "equalizer");
        compare(Media.stateIcon({playback_status: "Paused"}), "pause");
        compare(Media.stateIcon({playback_status: "Stopped"}), "stop");
        compare(Media.actionGroup({content_type: "music", control_mode: "seek"}, "next"), "overflow");
        compare(Media.actionGroup({content_type: "unknown", control_mode: "tracks"}, "next"), "toolbar");
        compare(Media.actionGroup({content_type: "podcast"}, "rewind"), "toolbar");
        compare(Media.identityLabel({id: "org.mpris.MediaPlayer2.chromium.instance42", identity: "Audible"}), "Audible · via Chrome");
    }
    function test_sourceLabels_data() {
        return [
            {tag: "zen-desktop", identity: "Mozilla zen", desktop: "zen", expected: "SoundCloud · via Zen"},
            {tag: "zen-identity", identity: "Mozilla zen", desktop: "", expected: "SoundCloud · via Zen"},
            {tag: "firefox", identity: "Mozilla Firefox", desktop: "firefox", expected: "SoundCloud · via Firefox"},
            {tag: "chromium", identity: "Chromium", desktop: "chromium", expected: "SoundCloud · via Chromium"},
            {tag: "chrome", identity: "Google Chrome", desktop: "google-chrome", expected: "SoundCloud · via Chrome"},
            {tag: "other-player", identity: "VLC", desktop: "vlc", expected: "SoundCloud · via VLC"},
            {tag: "no-duplicate", identity: "SoundCloud", desktop: "", expected: "SoundCloud"},
            {tag: "no-origin", identity: "", desktop: "", expected: "SoundCloud"}
        ];
    }
    function test_sourceLabels(data) {
        compare(Media.identityLabel({identity: data.identity, desktop_entry: data.desktop, source: {service: "soundcloud"}}), data.expected);
    }
    function test_timelineBoundariesAndStaleData() {
        const base = {length_us: 240000000, position_us: 60000000, position_observed_at_unix_ms: 10000, playback_rate: 2, playback_status: "playing"};
        let timing = Media.timeline(base, 12000);
        compare(timing.elapsed, "1:04");
        compare(timing.remaining, "−2:56");
        compare(timing.speed, "2×");
        compare(timing.fraction, 64 / 240);
        compare(Media.timeline(base, 999999999).elapsed, "1:10", "stale position freezes after five seconds");
        compare(Media.timeline(base, 9999).elapsed, "1:00", "future observation never advances backwards");
        compare(Media.timeline(Object.assign({}, base, {playback_status: "paused"}), 12000).elapsed, "1:00");
        compare(Media.timeline(Object.assign({}, base, {playback_rate: NaN}), 12000).elapsed, "1:00");
        compare(Media.timeline(Object.assign({}, base, {position_us: 999000000}), 12000).fraction, 1);
        compare(Media.timeline(Object.assign({}, base, {position_us: 999000000}), 12000).remaining, "−0:00");
        for (const invalid of [{length_us: 0}, {length_us: NaN}, {length_us: Infinity}, {position_us: -1}, {position_us: NaN}, {position_us: undefined}]) {
            timing = Media.timeline(Object.assign({}, base, invalid), 12000);
            verify(!timing.known);
            compare(timing.elapsed, "—:—");
            compare(timing.fraction, 0);
        }
        compare(Media.timeline(null, 12000).speed, "");
        compare(Media.durationText(3661000000), "1:01:01");
        compare(Media.timeline(Object.assign({}, base, {playback_rate: 1.25}), 10000).speed, "1.25×");
    }
}
