pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import "../../bar/BarApi.js" as BarApi

DaemonTestCase {
    id: testCase
    name: "BalancedDashboard"
    when: windowShown
    visible: true
    width: 1200
    height: 90
    Component {
        id: factory
        Bar.BarContent {
            id: bar
            width: 1200
            height: 51
            screenName: "test"
            property QtObject registry: QtObject {
                property var wifiController: null
                property var bluetoothController: null
                property var notificationState: null
                property var opened: []
                property string timeTab: ""
                function surfaceRequested(name: string): void { opened = opened.concat([name]); }
                function requestTimeWeatherTab(tab: string): void { timeTab = tab; }
            }
            controller: Bar.BarController {
                surfaceRegistry: bar.registry
                battery: ({available: true, percentage: 52, charging: true, plugged: true})
                workspaces: ({monitors: [{name: "test", active_workspace_id: 1}], focused_monitor: "test",
                    active_window: {class_name: "unrelated.application"}, workspaces: [
                        {id: 1, monitor: "test", windows: 1}, {id: 3, monitor: "test", windows: 2},
                        {id: 5, monitor: "test", windows: 0, urgent: true}]})
            }
        }
    }
    function init(): void {
        calls = [];
        failOnWarning(/.*/);
    }
    function acknowledge(bar, call): void {
        Io.DaemonSessions.sessions[bar.controller.backend.daemonName].client.response(call.id,
            {protocol: BarApi.protocol, version: BarApi.version, ok: true, data: {}}, "", call.route);
    }
    function fixture(): var {
        const bar = createTemporaryObject(factory, testCase);
        verify(bar !== null);
        wait(0);
        for (const call of calls) acknowledge(bar, call);
        calls = [];
        verify(waitForPolish(bar.Window.window));
        return bar;
    }
    function click(item): void { mouseClick(item, item.width / 2, item.height / 2); }

    function test_categoryIdentityAndAcknowledgedWorkspaceAction(): void {
        const bar = fixture();
        const glyphs = ["terminal", "language", "code", "music_note", "description"];
        const names = ["Shell", "Browser", "Code", "Media", "Text"];
        for (let i = 0; i < 5; ++i) {
            const button = findChild(bar, "barWorkspace:" + (i + 1));
            compare(button.width, 32);
            compare(findChild(button, "workspaceCategoryGlyph").symbol, glyphs[i]);
            verify(button.Accessible.name.includes(names[i]));
            verify(!button.activeFocusOnTab);
        }
        const shell = findChild(bar, "barWorkspace:1");
        const mediaWorkspace = findChild(bar, "barWorkspace:4");
        const text = findChild(bar, "barWorkspace:5");
        verify(shell.active);
        verify(!mediaWorkspace.occupied);
        verify(findChild(text, "workspaceUrgency").visible);
        click(mediaWorkspace);
        compare(calls.length, 1);
        compare(calls[0].method, BarApi.methods.workspaceFocus);
        compare(calls[0].params.workspace_id, 4);
        verify(calls[0].params.on_current_monitor);
        verify(shell.active && !mediaWorkspace.active, "request admission does not invent compositor acknowledgement");
        compare(bar.registry.opened.length, 0, "the Media category is not the media-panel opener");
        acknowledge(bar, calls[0]);
        bar.controller.workspaces = Object.assign({}, bar.controller.workspaces, {
            monitors: [{name: "test", active_workspace_id: 4}],
            active_window: {class_name: "a.different.app", initial_class: "another.icon"}
        });
        verify(mediaWorkspace.active && !shell.active);
        compare(findChild(mediaWorkspace, "workspaceCategoryGlyph").symbol, "music_note", "focused app never replaces category identity");
        compare(mediaWorkspace.width, 32, "selection never expands or labels its target");
        mediaWorkspace.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(calls.length, 2, "shared action-control keyboard route survives");
        compare(calls[1].params.workspace_id, 4);
    }
    function test_batteryReadingAndExternalMark_data(): var {
        return [
            {tag: "empty", state: {available: true, percentage: 0, critical: true}, fraction: 0, mark: "priority_high", word: "Critical"},
            {tag: "null-reading", state: {available: true, percentage: null}, fraction: 0, mark: "help_outline", word: "unavailable"},
        ];
    }
    function test_batteryReadingAndExternalMark(data): void {
        const bar = fixture();
        bar.controller.battery = data.state;
        const button = findChild(bar, "bar:battery");
        const gauge = findChild(button, "barBatteryGauge");
        const body = findChild(gauge, "barBatteryBody");
        const mark = findChild(gauge, "barBatteryStateMark");
        const fill = findChild(gauge, "barBatteryFill");
        const interior = findChild(gauge, "barBatteryInterior");
        compare(gauge.fraction, data.fraction);
        tryCompare(fill, "height", interior.height * data.fraction);
        compare(gauge.stateMark, data.mark);
        compare(mark.symbol, data.mark);
        verify(mark.x >= body.x + body.width + 4, "state mark has a real gap outside the battery body");
        verify(mark.clip, "fallback fonts cannot paint back over the gauge");
        compare(mark.visible, data.mark.length > 0);
        compare(fill.visible, data.mark !== "help_outline");
        verify(button.Accessible.name.includes(data.word));
        compare(button.width, 42, "empty state-mark slot remains reserved");
        if (mark.visible) click(mark);
        else click(body);
        compare(bar.registry.opened, ["battery"], "body and side mark share one existing panel route");
        button.Accessible.pressAction();
        compare(bar.registry.opened.length, 2);
        compare(calls.length, 0, "rendering and inspecting never change power policy");
    }
}
