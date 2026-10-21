pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
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
