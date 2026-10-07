pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import "../../bar/BarApi.js" as BarApi

DaemonTestCase {
    id: testCase
    name: "MediaSources"
    when: windowShown
    visible: true
    width: 1100
    height: 720

    Component {
        id: fixtureFactory
        Item {
            anchors.fill: parent
            property alias desktop: desktop
            property alias chooser: chooser
            property alias content: content
            Bar.BarController { id: desktop; surfaceRegistry: null }
            Bar.SystemChooserController { id: chooser; kind: "media"; barController: desktop }
            Bar.SystemChooserContent { id: content; anchors.fill: parent; controller: chooser }
        }
    }
    function init(): void { calls = []; failOnWarning(/.*/); }
    function cleanup(): void { Quickshell.themeIcons = {}; }
    function acknowledge(root, call): void {
        Io.DaemonSessions.sessions[root.desktop.backend.daemonName].client.response(call.id,
            {protocol: BarApi.protocol, version: BarApi.version, ok: true, data: {}}, "", call.route);
    }
    function fixture() {
        const root = createTemporaryObject(fixtureFactory, testCase);
        verify(root !== null);
        wait(0);
        for (const call of calls) acknowledge(root, call);
        calls = [];
        return root;
    }
    function player() {
        return {id: "org.mpris.MediaPlayer2.firefox.instance_1_380", identity: "Mozilla zen", desktop_entry: "zen",
            title: "Current recording", artist: "Creator", album: "", art_url: "", playback_status: "paused",
            control_mode: "automatic", content_type: "video", content_type_source: "url",
            source: {url: "https://vimeo.com/123456", service: "vimeo"},
            can_control: true, can_play: true, can_pause: true, can_seek: true, can_next: false, can_previous: false};
    }
    function publish(root, current): void {
        // The inspected browser is deliberately not the active/pinned player.
        root.desktop.media = {available: true, active_player: "other", pinned_player: "other",
            players: [current, {id: "other", identity: "Other", title: "Other recording", can_control: true}]};
    }
    function test_serviceIcons_data() {
        return [{tag: "service-theme", serviceIcon: true}, {tag: "browser-fallback", serviceIcon: false}];
    }
    function test_serviceIcons(data): void {
        const browserIcon = Qt.resolvedUrl("fixtures/media-cover.svg").toString();
        const serviceIcon = Qt.resolvedUrl("../../qml/Shelllist/Activity/assets/weather/clear-day.svg").toString();
        Quickshell.themeIcons = data.serviceIcon ? {zen: browserIcon, vimeo: serviceIcon} : {zen: browserIcon};
        const root = fixture();
        const p = player();
        publish(root, p);
        root.chooser.activateUi("");
        root.chooser.openDetails();
        tryVerify(() => findChild(root.content.detailsItem, "detailIdentityIcon") !== null);
        const icon = findChild(root.content.detailsItem, "detailIdentityIcon");
        compare(icon.iconSource.toString(), data.serviceIcon ? serviceIcon : browserIcon);
        tryCompare(icon, "hasImage", true);
        compare(findChild(root.content.detailsItem, "detailSubtitle").text, "Vimeo · via Zen");
        const card = findChild(root.content.detailsItem, "mediaPlayback");
        verify(!card.hasArtwork, "service/browser icons are never cover art");
        compare(calls.length, 0);
    }
    function test_youtubeEnrichmentKeepsTitleAndDraftAndClearsWithContent(): void {
        const root = fixture();
        let p = Object.assign(player(), {title: "A complete YouTube video title", artist: "",
            source: {url: "https://www.youtube.com/watch?v=RQzh-xnLRlM", service: "youtube"}});
        publish(root, p);
        root.chooser.activateUi("");
        root.chooser.openDetails();
        tryVerify(() => findChild(root.content.detailsItem, "detailTitle") !== null);
        const header = findChild(root.content.detailsItem, "detailTitle");
        const title = findChild(root.content.detailsItem, "mediaPlaybackTitle");
        const artwork = findChild(root.content.detailsItem, "mediaPlaybackArtwork");
        compare(header.text, "YouTube");
        compare(header.textFormat, Text.PlainText);
        compare(title.textFormat, Text.PlainText);
        compare(title.text, p.title);
        compare(artwork.status, Image.Null);
        root.content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaControlMode");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_End);
        p = Object.assign({}, p, {artist: "The <b>channel</b>", art_url: Qt.resolvedUrl("fixtures/media-cover.svg").toString(),
            metadata_sources: {artist: "youtube-oembed", art_url: "youtube-oembed"}});
        publish(root, p);
        tryCompare(header, "text", "The <b>channel</b>", 5000, "Provider text is literal, not rich text or resource URLs");
        tryCompare(artwork, "status", Image.Ready);
        compare(title.text, "A complete YouTube video title", "Enrichment never replaces a supplied title");
        verify(root.content.detailsNavigation.editing);
        compare(root.desktop.media.pinned_player, "other");
        compare(calls.length, 0, "Artwork/metadata never save drafts, select or invoke playback");
        keyClick(Qt.Key_Escape);
        compare(root.chooser.selectedPlayer.control_mode, "automatic");
        p = Object.assign({}, p, {title: "Next video", artist: "", art_url: "", metadata_sources: {},
            source: {url: "https://www.youtube.com/watch?v=abcdefghijk", service: "youtube"}});
        publish(root, p);
        tryCompare(header, "text", "YouTube");
        tryCompare(artwork, "status", Image.Null);
        compare(title.text, "Next video");
        compare(calls.length, 0, "Missing/restricted artwork keeps the passive fallback");
        keyClick(Qt.Key_P, Qt.AltModifier);
        compare(calls.length, 1);
        compare(calls[0].params.player_id, p.id, "Enrichment cannot reroute controls to the active player");
    }
    function test_sourceRefreshIsPassiveAndCommandsKeepPlayerTarget(): void {
        const root = fixture();
        let p = player();
        publish(root, p);
        root.chooser.activateUi("");
        root.chooser.openDetails();
        tryVerify(() => findChild(root.content.detailsItem, "detailSubtitle") !== null);
        const subtitle = findChild(root.content.detailsItem, "detailSubtitle");
        compare(subtitle.text, "Vimeo · via Zen");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaPlayerPin");
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaControlMode");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_End);
        // The browser moves to a different service while a settings draft exists.
        p = Object.assign({}, p, {source: {url: "https://soundcloud.com/artist/recording", service: "soundcloud"},
            content_type: "unknown", content_type_source: "unknown"});
        publish(root, p);
        tryCompare(subtitle, "text", "SoundCloud · via Zen");
        compare(calls.length, 0, "source refresh neither saves drafts nor dispatches playback");
        keyClick(Qt.Key_Escape);
        compare(root.chooser.selectedPlayer.control_mode, "automatic");
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaControlMode");
        root.chooser.filterText = "soundcloud";
        tryCompare(root.chooser.filteredResultsModel, "count", 1);
        compare(root.chooser.selectedResult.id, p.id);
        root.chooser.filterText = "";
        keyClick(Qt.Key_P, Qt.AltModifier);
        compare(calls.length, 1);
        compare(calls[0].method, "media.operation");
        compare(calls[0].params.player_id, p.id, "never route via source URL, service or active player");
        compare(calls[0].params.operation, "play-pause");
        acknowledge(root, calls[0]);
        calls = [];
        p = Object.assign({}, p, {source: null, can_control: false});
        publish(root, p);
        tryCompare(subtitle, "text", "Mozilla zen");
        compare(root.chooser.selectedPlayer.source, null, "cleared URL clears service presentation");
        keyClick(Qt.Key_P, Qt.AltModifier);
        compare(calls.length, 0, "source recognition never bypasses capability guards");
        compare(root.desktop.media.pinned_player, "other");
    }
}
