pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "ColorContrast.js" as Contrast
import "imports/Quickshell/Services/SystemTray" as TrayFixture
import "../../qml/Shelllist/Bar/BarApi.js" as BarApi
import "../../qml/Shelllist/Bar/SystemEntries.js" as Entries

DaemonTestCase {
    id: testCase
    name: "SystemChoosers"
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
    Component {
        id: trayFactory
        TrayFixture.SystemTrayItem { hasMenu: true; menu: QtObject {} }
    }
    property int previousScheme
    function init(): void { calls = []; failOnWarning(/.*/); previousScheme = Ui.Theme.previewColorScheme; }
    function cleanup(): void { clientReady = true; TrayFixture.SystemTray.items.values = []; Ui.Theme.previewColorScheme = previousScheme; }
    function acknowledge(fixture, call, data): void {
        Io.DaemonSessions.sessions[fixture.desktop.backend.daemonName].client.response(call.id, {protocol: BarApi.protocol, version: BarApi.version, ok: true, data: data || {}}, "", call.route);
    }
    function fixture() {
        const root = createTemporaryObject(fixtureFactory, testCase);
        verify(root !== null);
        wait(0);
        for (const call of calls)
            acknowledge(root, call, {});
        calls = [];
        compare(root.desktop.backend.pendingCount, 0, JSON.stringify(root.desktop.backend.pending));
        return root;
    }
    function player(id, seek) {
        return {id: id, identity: id, title: "Track " + id, playback_status: "Playing", can_control: true, can_pause: true, can_play: true, can_seek: seek};
    }
    function test_mediaArtworkFollowsMetadataWithoutChangingPlayback(): void {
        const root = fixture();
        const cover = Qt.resolvedUrl("fixtures/media-cover.svg").toString();
        const inlineCover = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80"><rect width="80" height="80" fill="white"/></svg>');
        // All clients use the same metadata path, including browser Media Session
        // covers. Inspecting a player must not borrow another active player's art.
        const other = Object.assign(player("other", true), {art_url: inlineCover, control_mode: "automatic"});
        let current = Object.assign(player("one", true), {art_url: cover, album: "Chapter 5", control_mode: "automatic"});
        root.desktop.media = {available: true, active_player: "other", pinned_player: null, players: [current, other]};
        root.chooser.activateUi("");
        root.chooser.openDetails();
        tryVerify(() => findChild(root.content.detailsItem, "mediaPlayback") !== null);
        const card = findChild(root.content.detailsItem, "mediaPlayback");
        const image = findChild(card, "mediaPlaybackArtwork");
        const title = findChild(card, "mediaPlaybackTitle");
        const subtitle = findChild(card, "mediaPlaybackSubtitle");
        tryCompare(image, "status", Image.Ready);
        compare(image.source.toString(), cover);
        verify(card.height >= 250 && card.height <= 300, "roughly 2.5 times the former compact card");
        compare(subtitle.text, "Chapter 5");
        for (const identity of ["Zen", "Chrome", "Audible", "Spotify", "Pocket Casts"]) {
            current = Object.assign({}, current, {identity: identity, title: identity + " current media", art_url: inlineCover});
            root.desktop.media = {available: true, active_player: "other", pinned_player: null, players: [current, other]};
            tryCompare(title, "text", identity + " current media");
            tryCompare(image, "status", Image.Ready);
            compare(decodeURIComponent(image.source.toString()), decodeURIComponent(inlineCover));
        }
        for (const scheme of [Qt.Light, Qt.Dark]) {
            Ui.Theme.previewColorScheme = scheme;
            verify(waitForPolish(card.Window.window));
            const pixels = grabImage(testCase);
            const point = title.mapToItem(testCase, -4, title.height / 2);
            const background = pixels.pixel(Math.round(point.x), Math.round(point.y));
            verify(Contrast.ratio(title.color, background) >= 4.5, "title contrast: " + title.color + " on " + background + " at " + point.x + "," + point.y);
            verify(Contrast.ratio(subtitle.color, background) >= 4.5, "metadata remains readable in either theme");
        }
        current = Object.assign({}, current, {art_url: "", title: "No cover supplied"});
        root.desktop.media = {available: true, active_player: "other", pinned_player: null, players: [current, other]};
        tryCompare(image, "status", Image.Null);
        verify(!card.hasArtwork, "never keep the previous cover when metadata clears it");
        compare(title.text, "No cover supplied");
        ignoreWarning(/.*QML (?:QQuick)?Image: Cannot open: .*missing-media-cover\.png/);
        current = Object.assign({}, current, {art_url: Qt.resolvedUrl("fixtures/missing-media-cover.png").toString()});
        root.desktop.media = {available: true, active_player: "other", pinned_player: null, players: [current, other]};
        tryCompare(image, "status", Image.Error);
        verify(!card.hasArtwork, "failed covers use the same fallback, not stale imagery");
        compare(title.color, Ui.Theme.text);
        root.chooser.selectedIndex = 1;
        tryCompare(title, "text", "Track other");
        tryCompare(image, "status", Image.Ready);
        compare(decodeURIComponent(image.source.toString()), decodeURIComponent(inlineCover));
        // The larger presentation remains passive; Tab still starts at settings.
        root.content.listItem.focusList();
        keyClick(Qt.Key_Tab);
        tryVerify(() => root.content.detailsNavigation.currentTarget !== null);
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaPlayerPin");
        keyClick(Qt.Key_Tab);
        compare(root.content.detailsNavigation.currentTarget.objectName, "mediaControlMode");
        root.content.visible = false;
        tryCompare(image, "status", Image.Null, 1000);
        compare(calls.length, 0, "artwork updates and field browsing never invoke playback or pinning");
    }
    function test_selectedPlayerIsExplicitAndCapabilitiesAreRevalidated(): void {
        const root = fixture();
        root.desktop.media = {available: true, active_player: "two", players: [player("one", true), player("two", true)]};
        root.chooser.activateUi("");
        tryCompare(root.chooser, "hasSelection", true);
        compare(root.chooser.selectedResult.id, "one");
        verify(root.chooser.triggerDetailAction("rewind"), JSON.stringify({busy: root.chooser.actionInFlight, calls: calls, actions: root.chooser.detailActions}));
        compare(calls.length, 1);
        compare(calls[0].params.player_id, "one");
        compare(calls[0].params.offset_seconds, -30);
        verify(!root.chooser.triggerDetailAction("rewind"), "busy requests are not replayed");
        acknowledge(root, calls[0], {});
        root.desktop.media = {available: true, active_player: "two", players: [player("one", false), player("two", true)]};
        verify(!root.chooser.triggerDetailAction("forward"));
        root.chooser.openDetails();
        root.chooser.deactivateUi();
        root.chooser.activateUi("");
        root.chooser.restoreUiFocus();
        wait(30);
        compare(calls.length, 1, "restoration does not activate playback");
        root.desktop.media = {available: true, active_player: "two", players: [player("two", true)]};
        verify(!root.chooser.perform("play-pause", "one"), "a disappeared player cannot fall through to the active one");
        clientReady = false;
        tryCompare(root.desktop.backend, "ready", false);
        verify(!root.chooser.triggerDetailAction("play-pause"), "stale disconnected capabilities cannot dispatch");
    }
    function test_audioBrowseDoesNotMuteAndOnlyAcknowledgementUpdatesState(): void {
        const root = fixture();
        root.chooser.kind = "audio";
        root.desktop.audio = {available: true, sink_name: "speakers", sink_description: "Speakers", volume_percent: 50, muted: false};
        root.chooser.activateUi("");
        root.chooser.primarySelected();
        const navigation = root.content.detailsNavigation;
        tryVerify(() => navigation.browsing && navigation.currentTarget !== null);
        for (let i = 0; i < 10 && navigation.currentTarget.objectName !== "audioMute"; ++i)
            keyClick(Qt.Key_Tab);
        compare(navigation.currentTarget.objectName, "audioMute");
        keyClick(Qt.Key_Space);
        compare(calls.length, 0);
        keyClick(Qt.Key_Return);
        compare(calls.length, 1);
        compare(calls[0].method, BarApi.methods.audioSetMuted);
        compare(root.desktop.audio.muted, false);
        acknowledge(root, calls[0], {audio: {available: true, sink_name: "speakers", sink_description: "Speakers", volume_percent: 50, muted: true}});
        compare(root.desktop.audio.muted, true);
        verify(root.desktop.triggerModuleAction("audio-mute"));
        compare(calls.length, 2);
        compare(calls[1].method, BarApi.methods.audioSetMuted);
    }
    function test_mediaPreferencesAreAcknowledgedAndDoNotReplayOnRestore(): void {
        const root = fixture();
        const p = Object.assign(player("one", true), {control_mode: "automatic", content_type: "unknown"});
        root.desktop.media = {available: true, active_player: "one", pinned_player: null, players: [p]};
        root.chooser.activateUi("");
        verify(root.chooser.setMediaMode("tracks"));
        compare(calls[0].params.operation, "set-mode");
        compare(calls[0].params.player_id, "one");
        compare(root.chooser.selectedPlayer.control_mode, "automatic");
        const changed = Object.assign({}, p, {control_mode: "tracks"});
        acknowledge(root, calls[0], {media: {available: true, active_player: "one", pinned_player: null, players: [changed]}});
        compare(root.chooser.selectedPlayer.control_mode, "tracks");
        verify(root.chooser.setMediaSelection(true));
        compare(calls[1].params.operation, "select");
        compare(root.chooser.playerPinned, false);
        acknowledge(root, calls[1], {media: {available: true, active_player: "one", pinned_player: "one", players: [changed]}});
        compare(root.chooser.playerPinned, true);
        root.chooser.deactivateUi();
        root.chooser.activateUi("");
        root.chooser.restoreUiFocus();
        wait(20);
        compare(calls.length, 2);
        verify(root.chooser.setMediaSelection(false));
        compare(calls[2].params.operation, "automatic");
    }
    function test_nativeTrayMenuOwnsFocusAndCannotSurviveInvocation(): void {
        const root = fixture();
        root.chooser.kind = "tray";
        root.chooser.activateUi("");
        root.content.listItem.focusSearch();
        const tray = createTemporaryObject(trayFactory, testCase);
        root.chooser.trayMenuRequested(tray);
        const menu = findChild(root, "systemTrayMenu");
        verify(menu.visible);
        verify(root.chooser.navigationBlocked);
        menu.close();
        verify(!root.chooser.navigationBlocked);
        verify(root.content.listItem.searchFocused);
        root.chooser.trayMenuRequested(tray);
        root.chooser.deactivateUi();
        verify(!menu.visible);
        verify(!root.chooser.navigationBlocked);
        root.chooser.activateUi("");
        menu.opened(); // Late native completion after the previous invocation.
        verify(!menu.visible);
        verify(!root.chooser.navigationBlocked);
        // The same retained tray entry may lose its native menu on reopening.
        tray.menu = null;
        root.chooser.trayMenuRequested(tray);
        verify(root.chooser.navigationBlocked);
        tryCompare(root.chooser, "navigationBlocked", false, 2500);
    }
    function test_trayProjectionNeverConfusesDuplicateOrPrototypeIdentities(): void {
        const values = Entries.tray([
            {id: "duplicate", title: "One", hasMenu: true},
            {id: "duplicate", title: "Two", hasMenu: true},
            {id: "__proto__", title: "Other", hasMenu: true, onlyMenu: true}
        ]);
        compare(values.length, 2);
        verify(values[0].actions.filter(action => action.id !== "inspect").every(action => !action.enabled));
        const other = values[1].actions;
        verify(other.find(action => action.id === "menu").enabled);
        verify(!other.find(action => action.id === "activate").enabled);
    }
}
