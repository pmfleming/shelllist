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
}
