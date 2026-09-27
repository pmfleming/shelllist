pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
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
    function init(): void { calls = []; failOnWarning(/.*/); }
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
            keyClick(Qt.Key_Down);
        compare(navigation.currentTarget.objectName, "audioMute");
        keyClick(Qt.Key_Space);
        compare(calls.length, 0);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Space);
        compare(calls.length, 1);
        compare(calls[0].method, BarApi.methods.audioSetMuted);
        compare(root.desktop.audio.muted, false);
        acknowledge(root, calls[0], {audio: {available: true, sink_name: "speakers", sink_description: "Speakers", volume_percent: 50, muted: true}});
        compare(root.desktop.audio.muted, true);
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
