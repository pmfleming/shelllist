pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import Shelllist.Ui as Ui
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
    function init(): void { calls = []; failOnWarning(/.*/); }
    function cleanup(): void { Ui.Theme.previewColorScheme = Qt.Unknown; }
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
        const shell = findChild(bar, "barWorkspace:1");
        const mediaWorkspace = findChild(bar, "barWorkspace:4");
        verify(shell.active);
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
        mediaWorkspace.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(calls.length, 2);
        compare(calls[1].params.workspace_id, 4);
    }
    function test_terminalPromptArtworkAndAction_data(): var {
        return [{tag: "dark", scheme: Qt.Dark}, {tag: "light", scheme: Qt.Light}];
    }
    function test_terminalPromptArtworkAndAction(data): void {
        Ui.Theme.previewColorScheme = data.scheme;
        const bar = fixture();
        const shell = findChild(bar, "barWorkspace:1");
        const icon = findChild(shell, "workspaceTerminalGlyph");
        verify(icon.visible);
        verify(!findChild(shell, "workspaceCategoryGlyph").visible);
        verify(!findChild(findChild(bar, "barWorkspace:4"), "workspaceTerminalGlyph").visible);
        compare(icon.color, Ui.Theme.accent);
        compare(icon.width, 22);
        verify(icon.bold);
        verify(icon.Accessible.ignored && !icon.activeFocusOnTab);
        verify(shell.Accessible.name.includes("Shell"));
        verify(waitForRendering(icon));
        // QtTest crops nested grabs in logical coordinates; sample the window
        // origin and account for its physical pixels on fractional/HiDPI screens.
        const pixels = grabImage(testCase);
        const origin = icon.mapToItem(testCase, 0, 0);
        const dpr = testCase.Screen.devicePixelRatio;
        function sample(x, y) {
            return pixels.pixel(Math.floor((origin.x + icon.width * x / 24) * dpr), Math.floor((origin.y + icon.height * y / 24) * dpr));
        }
        const background = sample(12, 12);
        verify(String(sample(9, 12)) !== String(background), "chevron paints");
        verify(String(sample(18, 19)) !== String(background), "underscore paints");
        compare(sample(12, 5), background, "no top frame");
        compare(sample(22, 12), background, "no right frame");

        bar.controller.workspaces = Object.assign({}, bar.controller.workspaces, {
            monitors: [{name: "test", active_workspace_id: 4}]
        });
        compare(icon.width, 20);
        compare(icon.color, Ui.Theme.text);
        verify(icon.bold);
        bar.controller.workspaces = Object.assign({}, bar.controller.workspaces, {
            workspaces: [{id: 1, monitor: "test", windows: 0, urgent: true}]
        });
        compare(icon.color, Ui.Theme.mutedText);
        verify(!icon.bold);
        verify(findChild(shell, "workspaceUrgency").visible);
        compare(calls.length, 0, "passive artwork and state changes never dispatch");
        click(icon);
        compare(calls.length, 1);
        compare(calls[0].method, BarApi.methods.workspaceFocus);
        compare(calls[0].params.workspace_id, 1);
        verify(!shell.active, "icon clicks still await compositor acknowledgement");
    }
    function test_batteryReadingAndExternalMark_data(): var {
        return [
            {tag: "null-reading", state: {available: true, percentage: null}, fraction: 0, mark: "help_outline", word: "unavailable"}
        ];
    }
    function test_batteryReadingAndExternalMark(data): void {
        const bar = fixture();
        bar.controller.battery = data.state;
        const button = findChild(bar, "bar:battery");
        const gauge = findChild(button, "barBatteryGauge");
        const mark = findChild(gauge, "barBatteryStateMark");
        const fill = findChild(gauge, "barBatteryFill");
        compare(gauge.fraction, data.fraction);
        compare(gauge.stateMark, data.mark);
        compare(mark.symbol, data.mark);
        compare(fill.visible, data.mark !== "help_outline");
        verify(button.Accessible.name.includes(data.word));
        click(mark);
        compare(bar.registry.opened, ["battery"]);
        button.Accessible.pressAction();
        compare(bar.registry.opened.length, 2);
        compare(calls.length, 0, "rendering and inspecting never change power policy");
    }
}
