pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
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
    function cleanup(): void { clientReady = true; TrayFixture.SystemTray.items.values = []; Quickshell.themeIcons = {}; Ui.Theme.previewColorScheme = previousScheme; }
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
    function test_mediaModeKeyboardDraftAndAcknowledgement(): void {
        const root = fixture();
        const p = Object.assign(player("one", true), {control_mode: "automatic", content_type: "music", can_next: true, can_previous: true});
        root.desktop.media = {available: true, active_player: "one", pinned_player: null, players: [p]};
        root.chooser.activateUi("");
        root.chooser.openDetails();
        tryVerify(() => root.content.detailsItem && findChild(root.content.detailsItem, "mediaControlMode") !== null);
        root.content.listItem.focusList();
        const nav = root.content.detailsNavigation;
        keyClick(Qt.Key_Tab);
        tryVerify(() => nav.currentTarget !== null);
        compare(nav.currentTarget.objectName, "mediaPlayerPin");
        keyClick(Qt.Key_Backtab, Qt.ShiftModifier);
        compare(nav.currentTarget.objectName, "mediaControlMode", "reverse traversal wraps over editable fields only");
        const mode = nav.currentTarget;
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_End);
        compare(calls.length, 0);
        keyClick(Qt.Key_Escape);
        compare(mode.value, "automatic");
        compare(calls.length, 0, "discarded mode never writes");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_Tab);
        compare(calls.length, 1);
        compare(calls[0].params.operation, "set-mode");
        compare(calls[0].params.mode, "seek");
        compare(root.chooser.selectedPlayer.control_mode, "automatic");
        acknowledge(root, calls[0], {media: {available: true, active_player: "one", pinned_player: null, players: [Object.assign({}, p, {control_mode: "seek"})]}});
        tryCompare(mode, "value", "seek");
        verify(findChild(root.content.detailsItem, "detailAction:rewind") !== null);
        verify(findChild(root.content.detailsItem, "detailAction:previous").visible, "bar mode never hides panel transport");
        compare(calls.length, 1);
        keyClick(Qt.Key_B, Qt.AltModifier);
        compare(calls.length, 2);
        compare(calls[1].params.player_id, "one");
        compare(calls[1].params.operation, "previous");
        acknowledge(root, calls[1], {});
        verify(root.chooser.setMediaSelection(true));
        compare(calls.length, 3);
        compare(calls[2].params.operation, "select");
        compare(calls[2].params.player_id, "one");
        verify(!root.chooser.playerPinned, "pin dispatch is not acknowledgement");
        acknowledge(root, calls[2], {media: {available: true, active_player: "one", pinned_player: "one", players: [Object.assign({}, p, {control_mode: "seek"})]}});
        verify(root.chooser.playerPinned);
        root.chooser.deactivateUi();
        root.chooser.activateUi("");
        root.chooser.restoreUiFocus();
        wait(20);
        compare(calls.length, 3, "restoring acknowledged preferences never replays them");
    }
    function test_mediaListEnterPrimary_data() {
        return [
            {tag: "paused-expanded", status: "Paused", expanded: true, key: Qt.Key_Enter}
        ];
    }
    function test_mediaListEnterPrimary(data): void {
        const root = fixture();
        const selected = Object.assign(player("selected", true), {playback_status: data.status});
        const active = player("active", true);
        root.desktop.media = {available: true, active_player: active.id, players: [active, selected]};
        root.chooser.activateUi("");
        root.content.listItem.focusSearch();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Down);
        compare(root.chooser.selectedResult.id, selected.id);
        compare(root.chooser.selectedResult.primaryActionId, "play-pause");
        keyClick(Qt.Key_Right);
        compare(root.chooser.detailsOpen, true);
        verify(root.content.listItem.listFocused);
        compare(calls.length, 0, "Right only inspects the player");
        if (!data.expanded)
            keyClick(Qt.Key_Left);
        keyClick(data.key);
        compare(calls.length, 1);
        compare(calls[0].params.player_id, selected.id, "never route to the active player");
        compare(calls[0].params.operation, "play-pause");
        compare(root.chooser.detailsOpen, data.expanded);
        verify(root.content.listItem.listFocused, "primary action keeps list focus");
        compare(root.chooser.selectedPlayer.playback_status, data.status, "no optimistic playback state");
        keyClick(data.key);
        compare(calls.length, 1, "busy Enter does not replay");
        acknowledge(root, calls[0], {});
        const blocked = Object.assign({}, selected, data.status === "Playing" ? {can_pause: false} : {can_play: false});
        root.desktop.media = {available: true, active_player: active.id, players: [active, blocked]};
        keyClick(data.key);
        compare(calls.length, 1, "unavailable primary does not dispatch or fall back to inspection");
        compare(root.chooser.detailsOpen, data.expanded);
        root.desktop.media = {available: true, active_player: active.id, players: [active]};
        verify(!root.chooser.perform("play-pause", selected.id), "a disappeared player cannot fall through to the active one");
        clientReady = false;
        tryCompare(root.desktop.backend, "ready", false);
        keyClick(data.key);
        compare(calls.length, 1, "disconnected Enter cannot dispatch");
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
