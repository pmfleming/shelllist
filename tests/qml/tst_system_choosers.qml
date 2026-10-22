pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
import "imports/Quickshell" as QuickshellFixture
import "imports/Quickshell/Services/SystemTray" as TrayFixture
import "../../qml/Shelllist/Bar/BarApi.js" as BarApi

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
    Component { id: residentFactory; Bar.BarController { surfaceRegistry: null } }
    Component { id: lateTrayFactory; Bar.SystemChooserController { kind: "tray" } }
    property int previousScheme
    property var previousEnvironment
    function init(): void { calls = []; failOnWarning(/.*/); previousScheme = Ui.Theme.previewColorScheme; previousEnvironment = QuickshellFixture.Quickshell.environment; }
    function cleanup(): void { clientReady = true; TrayFixture.SystemTray.items.values = []; Quickshell.themeIcons = {}; Ui.Theme.previewColorScheme = previousScheme; QuickshellFixture.Quickshell.environment = previousEnvironment; }
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
    function mediaPlayer(id, status) {
        return {id: id, identity: id, title: id, playback_status: status,
            can_control: true, can_play: true, can_pause: true, control_mode: "automatic"};
    }
    function mediaIndicator(root, id) {
        const row = findChild(root.content, "systemResult:" + id);
        return row ? findChild(row, "mediaSessionState") : null;
    }
    function test_playingIndicatorFollowsPlaybackAndPanelLifetime_data() {
        return [{tag: "animated", motion: true}, {tag: "reduced-motion", motion: false}];
    }
    function test_playingIndicatorFollowsPlaybackAndPanelLifetime(data): void {
        QuickshellFixture.Quickshell.environment = Object.assign({}, previousEnvironment, {SHELLLIST_NO_ANIMATIONS: data.motion ? "0" : "1"});
        const root = fixture();
        function publish(status) {
            root.desktop.media = {players: [mediaPlayer("playing", status), mediaPlayer("paused", "Paused")],
                active_player: "playing", pinned_player: ""};
        }
        publish("Playing");
        root.chooser.activateUi("");
        tryVerify(() => mediaIndicator(root, "playing") !== null);
        const indicator = mediaIndicator(root, "playing");
        const bar = findChild(indicator, "playbackBar0");
        const animation = findChild(bar, "playbackBarAnimation");
        tryCompare(indicator, "animating", data.motion);
        compare(animation.running, data.motion);
        verify(!mediaIndicator(root, "paused").animating);
        const width = indicator.width;
        const height = indicator.height;
        const initialLevel = bar.level;
        if (data.motion)
            tryVerify(() => Math.abs(bar.level - initialLevel) > 0.05, 1000, "actual native animation advances the bars");
        else {
            wait(120);
            compare(bar.level, initialLevel);
        }
        compare(indicator.width, width);
        compare(indicator.height, height);
        mouseClick(findChild(root.content, "systemResult:paused"));
        compare(root.chooser.selectedPlayer.id, "paused");
        compare(indicator.animating, data.motion, "playing rows animate independently of selection");
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_Tab);
        tryVerify(() => root.content.detailsNavigation.currentTarget !== null);
        verify(root.content.detailsNavigation.currentTarget !== indicator, "status remains passive, never an editable stop");
        verify(!indicator.activeFocusOnTab);

        publish("Paused");
        tryCompare(indicator, "glyph", "pause");
        verify(!animation.running);
        publish("Stopped");
        tryCompare(indicator, "glyph", "stop");
        verify(!indicator.animating);
        publish("Playing");
        tryCompare(indicator, "animating", data.motion);
        root.chooser.deactivateUi();
        tryCompare(animation, "running", false);
        const stoppedLevel = bar.level;
        wait(120);
        compare(bar.level, stoppedLevel, "closing the panel stops animation work, not just its paint");
        root.chooser.activateUi("");
        tryCompare(indicator, "animating", data.motion);
        root.content.visible = false;
        tryCompare(animation, "running", false);
        root.content.visible = true;
        tryCompare(indicator, "animating", data.motion);
        QuickshellFixture.Quickshell.environment = Object.assign({}, previousEnvironment, {SHELLLIST_NO_ANIMATIONS: "1"});
        tryCompare(animation, "running", false);
        compare(bar.height, indicator.height * bar.restLevel, "reduced motion retains a static equalizer");
        QuickshellFixture.Quickshell.environment = Object.assign({}, previousEnvironment, {SHELLLIST_NO_ANIMATIONS: "0"});
        tryCompare(indicator, "animating", true);
        clientReady = false;
        tryCompare(indicator, "animating", false);
        compare(calls.length, 0, "presentation and browsing must not send playback or preference writes");
    }
    function test_playingIndicatorStopsOutsideTheListViewport(): void {
        QuickshellFixture.Quickshell.environment = Object.assign({}, previousEnvironment, {SHELLLIST_NO_ANIMATIONS: "0"});
        const root = fixture();
        root.desktop.media = {players: Array.from({length: 20}, (_, i) => mediaPlayer("player-" + i, "Playing")),
            active_player: "player-0", pinned_player: ""};
        root.chooser.activateUi("");
        tryVerify(() => mediaIndicator(root, "player-0") !== null);
        const indicator = mediaIndicator(root, "player-0");
        const list = findChild(root.content, "resultListView");
        // Retain the offscreen delegate so the test proves suspension rather
        // than merely relying on ListView destroying it.
        list.cacheBuffer = 10000;
        tryVerify(() => list.contentHeight > list.height && indicator.animating);
        wait(0);
        list.contentY = list.contentHeight - list.height;
        tryCompare(indicator, "animating", false);
        verify(!findChild(findChild(indicator, "playbackBar0"), "playbackBarAnimation").running);
        list.contentY = list.originY;
        tryCompare(indicator, "animating", true);
        compare(calls.length, 0);
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
    function test_residentBarCollectsTrayItemsBeforeTheChooserExists(): void {
        const resident = createTemporaryObject(residentFactory, testCase);
        const updates = createTemporaryObject(trayFactory, testCase, {id: "shelllist-updates", title: "Shelllist Updates"});
        TrayFixture.SystemTray.items.values = [updates];
        compare(resident.trayItems.length, 1);
        compare(resident.trayItems[0], updates);
        const chooser = createTemporaryObject(lateTrayFactory, testCase, {barController: resident});
        compare(chooser.sourceEntries.length, 1);
        chooser.activateUi("");
        compare(chooser.filteredResults[0].id, "shelllist-updates");
        compare(updates.activationCount, 0);
        chooser.deactivateUi();
        TrayFixture.SystemTray.items.values = [];
        compare(resident.trayItems.length, 0);
    }
    function test_trayCommandsKeepLiveIdentityAndInvocationGuards(): void {
        const root = fixture();
        const tray = createTemporaryObject(trayFactory, testCase, {id: "__proto__", title: "Tray app"});
        TrayFixture.SystemTray.items.values = [tray];
        root.chooser.kind = "tray";
        root.chooser.activateUi("");
        root.content.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => root.content.detailsItem && root.content.detailsNavigation.contentReady);
        keyClick(Qt.Key_U, Qt.AltModifier);
        compare(tray.scrollTotal, 15);
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(tray.scrollTotal, 0);
        keyClick(Qt.Key_A, Qt.AltModifier);
        compare(tray.activationCount, 1);
        root.chooser.trayMenuActive = true;
        verify(!root.chooser.perform("scroll-up", tray.id));
        root.chooser.trayMenuActive = false;
        const duplicate = createTemporaryObject(trayFactory, testCase, {id: tray.id});
        TrayFixture.SystemTray.items.values = [tray, duplicate];
        verify(!root.chooser.perform("activate", tray.id));
        compare(duplicate.activationCount, 0);
        root.chooser.deactivateUi();
        verify(!root.chooser.perform("activate", tray.id));
        compare(tray.activationCount, 1);
    }
}
